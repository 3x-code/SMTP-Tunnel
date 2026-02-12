package main

import (
	"crypto/tls"
	"encoding/binary"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"gopkg.in/yaml.v3"
)

type ServerConfig struct {
	Server struct {
		Host     string `yaml:"host"`
		Port     int    `yaml:"port"`
		Hostname string `yaml:"hostname"`
	} `yaml:"server"`
	TLS struct {
		CertFile string `yaml:"cert_file"`
		KeyFile  string `yaml:"key_file"`
		Mode     string `yaml:"mode"`
		Domain   string `yaml:"domain"`
		Email    string `yaml:"email"`
	} `yaml:"tls"`
	Users map[string]struct {
		Secret    string   `yaml:"secret"`
		Whitelist []string `yaml:"whitelist"`
		Logging   bool     `yaml:"logging"`
	} `yaml:"users"`
	Logging struct {
		Level string `yaml:"level"`
		File  string `yaml:"file"`
	} `yaml:"logging"`
}

var (
	version = "v0.2.0"
	config  ServerConfig
	logger  *Logger
)

type Logger struct {
	level string
}

func (l *Logger) Info(msg string, args ...interface{}) {
	fmt.Printf("[INFO] "+msg+"\n", args...)
}
func (l *Logger) Error(msg string, args ...interface{}) {
	fmt.Printf("[ERROR] "+msg+"\n", args...)
}
func (l *Logger) Debug(msg string, args ...interface{}) {
	if l.level == "debug" {
		fmt.Printf("[DEBUG] "+msg+"\n", args...)
	}
}

type Channel struct {
	ID        uint16
	Conn      net.Conn
	CreatedAt time.Time
	mu        sync.Mutex
}

type Server struct {
	config     *ServerConfig
	tlsConfig  *tls.Config
	channels   map[uint16]*Channel
	channelsMu sync.RWMutex
	nextID     uint16
	logger     *Logger
}

func main() {
	configFile := flag.String("config", "/etc/smtp-tunnel/server.yaml", "Config file path")
	versionFlag := flag.Bool("version", false, "Show version")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("SMTP-Tunnel Server %s\n", version)
		os.Exit(0)
	}

	// Load config
	data, err := os.ReadFile(*configFile)
	if err != nil {
		fmt.Printf("Error loading config: %v\n", err)
		os.Exit(1)
	}

	err = yaml.Unmarshal(data, &config)
	if err != nil {
		fmt.Printf("Error parsing config: %v\n", err)
		os.Exit(1)
	}

	logger = &Logger{level: config.Logging.Level}
	logger.Info("SMTP-Tunnel Server %s starting...", version)

	// Setup TLS
	var tlsConfig *tls.Config
	cert, err := tls.LoadX509KeyPair(config.TLS.CertFile, config.TLS.KeyFile)
	if err != nil {
		logger.Error("Failed to load certificate: %v", err)
		os.Exit(1)
	}
	tlsConfig = &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   config.Server.Hostname,
	}
	logger.Info("TLS certificates loaded")

	server := &Server{
		config:    &config,
		tlsConfig: tlsConfig,
		channels:  make(map[uint16]*Channel),
		logger:    logger,
		nextID:    1,
	}

	addr := fmt.Sprintf("%s:%d", config.Server.Host, config.Server.Port)
	listener, err := tls.Listen("tcp", addr, tlsConfig)
	if err != nil {
		logger.Error("Failed to listen: %v", err)
		os.Exit(1)
	}
	defer listener.Close()

	logger.Info("Server listening on %s", addr)
	logger.Info("Users configured: %d", len(config.Users))

	// Handle shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		logger.Info("Shutting down...")
		os.Exit(0)
	}()

	for {
		conn, err := listener.Accept()
		if err != nil {
			logger.Error("Accept error: %v", err)
			continue
		}
		go server.handleConnection(conn)
	}
}

func (s *Server) handleConnection(conn net.Conn) {
	defer conn.Close()
	clientAddr := conn.RemoteAddr().String()
	s.logger.Info("New connection from %s", clientAddr)

	// SMTP Handshake
	if !s.smtpHandshake(conn) {
		return
	}

	// Binary mode loop
	buffer := make([]byte, 65536)
	for {
		n, err := conn.Read(buffer)
		if err != nil {
			break
		}
		if n > 0 {
			s.processFrame(conn, buffer[:n])
		}
	}
}

func (s *Server) smtpHandshake(conn net.Conn) bool {
	// Send greeting
	fmt.Fprintf(conn, "220 %s ESMTP Postfix\r\n", s.config.Server.Hostname)

	// Read EHLO
	buf := make([]byte, 1024)
	n, _ := conn.Read(buf)
	if !strings.Contains(string(buf[:n]), "EHLO") {
		return false
	}

	// Send capabilities
	fmt.Fprintf(conn, "250-%s\r\n", s.config.Server.Hostname)
	fmt.Fprintf(conn, "250-STARTTLS\r\n")
	fmt.Fprintf(conn, "250-AUTH PLAIN LOGIN\r\n")
	fmt.Fprintf(conn, "250 8BITMIME\r\n")

	// Read STARTTLS
	n, _ = conn.Read(buf)
	if !strings.Contains(string(buf[:n]), "STARTTLS") {
		return false
	}
	fmt.Fprintf(conn, "220 Ready to start TLS\r\n")

	// TLS already handled by listener
	return true
}

func (s *Server) processFrame(conn net.Conn, data []byte) {
	if len(data) < 5 {
		return
	}

	frameType := data[0]
	channelID := binary.BigEndian.Uint16(data[1:3])
	payloadLen := binary.BigEndian.Uint16(data[3:5])

	if len(data) < 5+int(payloadLen) {
		return
	}

	payload := data[5 : 5+payloadLen]

	switch frameType {
	case 0x02:
		s.handleConnect(conn, channelID, payload)
	case 0x01:
		s.handleData(channelID, payload)
	case 0x05:
		s.handleClose(channelID)
	}
}

func (s *Server) handleConnect(conn net.Conn, channelID uint16, payload []byte) {
	hostLen := payload[0]
	host := string(payload[1 : 1+hostLen])
	port := binary.BigEndian.Uint16(payload[1+hostLen : 3+hostLen])

	s.logger.Info("Channel %d: Connecting to %s:%d", channelID, host, port)

	targetConn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", host, port), 30*time.Second)
	if err != nil {
		s.logger.Error("Channel %d: Connection failed: %v", channelID, err)
		conn.Write([]byte{0x04, byte(channelID >> 8), byte(channelID), 0, 0})
		return
	}

	channel := &Channel{
		ID:        channelID,
		Conn:      targetConn,
		CreatedAt: time.Now(),
	}

	s.channelsMu.Lock()
	s.channels[channelID] = channel
	s.channelsMu.Unlock()

	conn.Write([]byte{0x03, byte(channelID >> 8), byte(channelID), 0, 0})

	go s.forwardToClient(channelID, targetConn, conn)
}

func (s *Server) handleData(channelID uint16, payload []byte) {
	s.channelsMu.RLock()
	channel, exists := s.channels[channelID]
	s.channelsMu.RUnlock()

	if exists {
		channel.mu.Lock()
		channel.Conn.Write(payload)
		channel.mu.Unlock()
	}
}

func (s *Server) handleClose(channelID uint16) {
	s.channelsMu.Lock()
	if channel, exists := s.channels[channelID]; exists {
		channel.Conn.Close()
		delete(s.channels, channelID)
		s.logger.Debug("Channel %d closed", channelID)
	}
	s.channelsMu.Unlock()
}

func (s *Server) forwardToClient(channelID uint16, targetConn net.Conn, clientConn net.Conn) {
	buffer := make([]byte, 32768)
	for {
		n, err := targetConn.Read(buffer)
		if err != nil {
			break
		}
		if n > 0 {
			frame := make([]byte, 5+n)
			frame[0] = 0x01
			binary.BigEndian.PutUint16(frame[1:3], channelID)
			binary.BigEndian.PutUint16(frame[3:5], uint16(n))
			copy(frame[5:], buffer[:n])
			clientConn.Write(frame)
		}
	}
	s.handleClose(channelID)
}
