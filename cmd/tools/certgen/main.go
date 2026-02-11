package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"flag"
	"fmt"
	"math/big"
	"net"
	"os"
	"strings"
	"time"
)

func main() {
	var (
		host      = flag.String("host", "", "Comma-separated hostnames and IPs")
		certFile  = flag.String("cert", "server.crt", "Certificate output file")
		keyFile   = flag.String("key", "server.key", "Private key output file")
		rsaBits   = flag.Int("rsa-bits", 2048, "Size of RSA key")
	)
	flag.Parse()

	if *host == "" {
		fmt.Fprintln(os.Stderr, "Host is required")
		os.Exit(1)
	}

	priv, err := rsa.GenerateKey(rand.Reader, *rsaBits)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to generate private key: %v\n", err)
		os.Exit(1)
	}

	notBefore := time.Now()
	notAfter := notBefore.Add(365 * 24 * time.Hour)

	serialNumberLimit := new(big.Int).Lsh(big.NewInt(1), 128)
	serialNumber, err := rand.Int(rand.Reader, serialNumberLimit)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to generate serial number: %v\n", err)
		os.Exit(1)
	}

	template := x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			Organization: []string{"SMTP-Tunnel"},
			CommonName:   *host,
		},
		NotBefore: notBefore,
		NotAfter:  notAfter,

		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
	}

	hosts := strings.Split(*host, ",")
	for _, h := range hosts {
		h = strings.TrimSpace(h)
		if ip := net.ParseIP(h); ip != nil {
			template.IPAddresses = append(template.IPAddresses, ip)
		} else {
			template.DNSNames = append(template.DNSNames, h)
		}
	}

	derBytes, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create certificate: %v\n", err)
		os.Exit(1)
	}

	// Save certificate
	certOut, err := os.Create(*certFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to open %s for writing: %v\n", *certFile, err)
		os.Exit(1)
	}
	defer certOut.Close()
	
	pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: derBytes})

	// Save private key
	keyOut, err := os.OpenFile(*keyFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to open %s for writing: %v\n", *keyFile, err)
		os.Exit(1)
	}
	defer keyOut.Close()
	
	pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv)})

	fmt.Printf("✅ Certificate generated successfully:\n")
	fmt.Printf("  Certificate: %s\n", *certFile)
	fmt.Printf("  Private key: %s\n", *keyFile)
}
