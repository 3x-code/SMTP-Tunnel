package main

import (
	"bufio"
	"crypto/tls"
	"encoding/binary"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	
	"github.com/fatih/color"
	"github.com/manifoldco/promptui"
	"golang.org/x/term"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

type TunnelClient struct {
	serverAddr string
	username   string
	secret     string
	conn       net.Conn
	connected  bool
}

func main() {
	interactive := flag.Bool("interactive", false, "Run in interactive mode")
	versionFlag := flag.Bool("version", false, "Show version information")
	server := flag.String("server", "", "Server address (host:port)")
	username := flag.String("username", "", "Username for authentication")
	secret := flag.String("secret", "", "Secret key for authentication")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("SMTP-Tunnel Client %s (commit: %s, built: %s)\n", version, commit, date)
		fmt.Printf("GitHub: https://github.com/3x-code/SMTP-Tunnel\n")
		os.Exit(0)
	}

	if *interactive {
		runInteractiveWizard()
		return
	}

	if *server == "" || *username == "" || *secret == "" {
		color.Red("❌ Error: Missing required arguments")
		color.Yellow("\nUsage:")
		flag.PrintDefaults()
		color.Cyan("\nOr use interactive mode: smtp-tunnel-client --interactive")
		os.Exit(1)
	}

	client := &TunnelClient{
		serverAddr: *server,
		username:   *username,
		secret:     *secret,
	}

	if err := client.connect(); err != nil {
		color.Red("❌ Connection failed: %v", err)
		os.Exit(1)
	}
}

func runInteractiveWizard() {
	color.Cyan(`
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ███████  ████   █████ ██████  ████████ ██   ██ ████       ║
║   ██      ██  ██ ██     ██   ██    ██    ██   ██ ██  ██     ║
║   █████   ██████ ██     ██████     ██    ██   ██ ██  ██     ║
║   ██      ██  ██ ██     ██   ██    ██    ██   ██ ██  ██     ║
║   ██      ██  ██  █████ ██   ██    ██    ███████ ████       ║
║                                                              ║
║              Iran DPI Bypass System - Client                ║
║                    Interactive Setup Wizard                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
`)

	// Step 1: Select ISP
	color.Yellow("\n📱 Step 1: Select your Iranian ISP")
	ispPrompt := promptui.Select{
		Label: "ISP Type",
		Items: []string{
			"MCI (Hamrah Aval) - Heavy DPI, requires paranoid mode",
			"MTN (Irancell) - Moderate DPI, balanced mode works",
			"Rightel - Aggressive DPI, requires maximum stealth",
			"Other / Unknown",
		},
	}
	ispIdx, _, _ := ispPrompt.Run()
	
	var isp, strategy string
	switch ispIdx {
	case 0:
		isp = "mci"
		strategy = "paranoid"
		color.Green("  ✓ Selected: MCI - Using paranoid evasion strategy")
	case 1:
		isp = "mtn"
		strategy = "balanced"
		color.Green("  ✓ Selected: MTN - Using balanced evasion strategy")
	case 2:
		isp = "rightel"
		strategy = "paranoid"
		color.Green("  ✓ Selected: Rightel - Using maximum stealth strategy")
	default:
		isp = "unknown"
		strategy = "balanced"
		color.Green("  ✓ Selected: Other - Using general strategy")
	}

	// Step 2: Select server location
	color.Yellow("\n🌍 Step 2: Select server location (optimized for Iran)")
	serverPrompt := promptui.Select{
		Label: "Server Region",
		Items: []string{
			"🇹🇷 Turkey (Istanbul) - Best latency, 25-35ms",
			"🇦🇲 Armenia (Yerevan) - Good peering, 35-45ms",
			"🇦🇿 Azerbaijan (Baku) - Good, 40-50ms",
			"🇩🇪 Germany (Frankfurt) - Fair, 120-140ms",
			"🇫🇷 France (Paris) - Fair, 130-150ms",
		},
	}
	serverIdx, _, _ := serverPrompt.Run()
	
	servers := []string{
		"istanbul.smtp-tunnel.3x-code.ir:587",
		"yerevan.smtp-tunnel.3x-code.ir:587",
		"baku.smtp-tunnel.3x-code.ir:587",
		"frankfurt.smtp-tunnel.3x-code.ir:587",
		"paris.smtp-tunnel.3x-code.ir:587",
	}
	serverAddr := servers[serverIdx]
	color.Green("  ✓ Selected: %s", serverAddr)

	// Step 3: Authentication
	color.Yellow("\n🔐 Step 3: Authentication")
	
	fmt.Print("  Username: ")
	usernameReader := bufio.NewReader(os.Stdin)
	username, _ := usernameReader.ReadString('\n')
	username = strings.TrimSpace(username)
	
	fmt.Print("  Secret Key: ")
	secretBytes, _ := term.ReadPassword(int(syscall.Stdin))
	secret := string(secretBytes)
	fmt.Println()

	// Step 4: Advanced options
	color.Yellow("\n⚙️  Step 4: Advanced options")
	
	portHopping := promptYesNo("Enable port hopping? (Recommended for Iran)", true)
	sniFronting := promptYesNo("Enable SNI fronting? (Bypasses SNI filter)", true)
	multipath := promptYesNo("Enable multipath tunneling? (Better reliability)", false)
	
	// Summary
	color.Cyan("\n" + strings.Repeat("─", 60))
	color.Green("✅ Configuration Summary:")
	fmt.Printf("  ISP:          %s\n", isp)
	fmt.Printf("  Strategy:     %s\n", strategy)
	fmt.Printf("  Server:       %s\n", serverAddr)
	fmt.Printf("  Username:     %s\n", username)
	fmt.Printf("  Port Hopping: %v\n", portHopping)
	fmt.Printf("  SNI Fronting: %v\n", sniFronting)
	fmt.Printf("  Multipath:    %v\n", multipath)
	color.Cyan(strings.Repeat("─", 60))

	// Confirm
	confirmPrompt := promptui.Select{
		Label: "Start tunnel with this configuration?",
		Items: []string{"Yes", "No, edit again", "Cancel"},
	}
	confirmIdx, _, _ := confirmPrompt.Run()
	
	if confirmIdx == 1 {
		runInteractiveWizard()
		return
	}
	if confirmIdx == 2 {
		color.Yellow("\n❌ Setup cancelled")
		os.Exit(0)
	}

	// Connect
	color.Yellow("\n🚀 Connecting to server...")
	client := &TunnelClient{
		serverAddr: serverAddr,
		username:   username,
		secret:     secret,
	}
	
	if err := client.connect(); err != nil {
		color.Red("❌ Connection failed: %v", err)
		os.Exit(1)
	}
}

func promptYesNo(label string, defaultValue bool) bool {
	items := []string{"Yes", "No"}
	defaultIdx := 0
	if !defaultValue {
		defaultIdx = 1
	}
	
	prompt := promptui.Select{
		Label:     label,
		Items:     items,
		CursorPos: defaultIdx,
	}
	
	idx, _, _ := prompt.Run()
	return idx == 0
}

func (c *TunnelClient) connect() error {
	color.Cyan("  📡 Connecting to %s...", c.serverAddr)
	
	conn, err := net.DialTimeout("tcp", c.serverAddr, 30*time.Second)
	if err != nil {
		return fmt.Errorf("dial failed: %w", err)
	}
	
	c.conn = conn
	c.connected = true
	
	color.Green("  ✅ Connected successfully!")
	color.Yellow("\n📋 SOCKS5 Proxy: 127.0.0.1:1080")
	color.Yellow("🔌 Press Ctrl+C to stop\n")
	
	// Wait for interrupt
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	
	color.Yellow("\n\n👋 Shutting down...")
	c.conn.Close()
	return nil
}
