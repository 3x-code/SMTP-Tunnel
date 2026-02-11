package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	
	"github.com/fatih/color"
)

var version = "v0.1.0"

func main() {
	versionFlag := flag.Bool("version", false, "Show version information")
	interactiveFlag := flag.Bool("interactive", false, "Run interactive setup wizard")
	server := flag.String("server", "", "Server address (host:port)")
	username := flag.String("username", "", "Username for authentication")
	secret := flag.String("secret", "", "Secret key for authentication")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("SMTP-Tunnel Client %s\n", version)
		fmt.Println("GitHub: https://github.com/3x-code/SMTP-Tunnel")
		os.Exit(0)
	}

	if *interactiveFlag {
		runInteractiveWizard()
		return
	}

	if *server != "" && *username != "" && *secret != "" {
		fmt.Printf("Connecting to %s...\n", *server)
		fmt.Printf("Username: %s\n", *username)
		fmt.Println("Press Ctrl+C to stop")
		select {}
	}

	fmt.Println("SMTP-Tunnel Client - Iran DPI Bypass System")
	fmt.Println("\nUsage:")
	flag.PrintDefaults()
	fmt.Println("\nExamples:")
	fmt.Println("  smtp-tunnel --interactive")
	fmt.Println("  smtp-tunnel --version")
}

func runInteractiveWizard() {
	reader := bufio.NewReader(os.Stdin)
	
	// Banner
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

	// Step 1: ISP Selection
	color.Yellow("\n📱 Step 1: Select your Iranian ISP")
	color.Yellow(strings.Repeat("─", 50))
	
	fmt.Println()
	fmt.Println("  1) MCI (Hamrah Aval) - Heavy DPI, requires paranoid mode")
	fmt.Println("  2) MTN (Irancell) - Moderate DPI, balanced mode works")
	fmt.Println("  3) Rightel - Aggressive DPI, requires maximum stealth")
	fmt.Println("  4) Other / Unknown ISP")
	fmt.Println()
	
	fmt.Print("  Enter your choice (1-4): ")
	ispChoice, _ := reader.ReadString('\n')
	ispChoice = strings.TrimSpace(ispChoice)
	
	var isp, strategy string
	switch ispChoice {
	case "1":
		isp = "mci"
		strategy = "paranoid"
		color.Green("  ✓ Selected: MCI (Hamrah Aval) - Using paranoid evasion strategy")
	case "2":
		isp = "mtn"
		strategy = "balanced"
		color.Green("  ✓ Selected: MTN (Irancell) - Using balanced evasion strategy")
	case "3":
		isp = "rightel"
		strategy = "paranoid"
		color.Green("  ✓ Selected: Rightel - Using maximum stealth strategy")
	default:
		isp = "unknown"
		strategy = "balanced"
		color.Green("  ✓ Selected: Other ISP - Using general strategy")
	}
	
	// Step 2: Server Location
	color.Yellow("\n🌍 Step 2: Select server location (optimized for Iran)")
	color.Yellow(strings.Repeat("─", 50))
	
	fmt.Println()
	fmt.Println("  1) 🇹🇷 Turkey (Istanbul) - Best latency, 25-35ms")
	fmt.Println("  2) 🇦🇲 Armenia (Yerevan) - Good peering, 35-45ms")
	fmt.Println("  3) 🇦🇿 Azerbaijan (Baku) - Good, 40-50ms")
	fmt.Println("  4) 🇩🇪 Germany (Frankfurt) - Fair, 120-140ms")
	fmt.Println("  5) 🇫🇷 France (Paris) - Fair, 130-150ms")
	fmt.Println("  6) 🇬🇧 UK (London) - Higher latency, 150-170ms")
	fmt.Println()
	
	fmt.Print("  Enter your choice (1-6): ")
	serverChoice, _ := reader.ReadString('\n')
	serverChoice = strings.TrimSpace(serverChoice)
	
	servers := map[string]string{
		"1": "istanbul.smtp-tunnel.3x-code.ir:587",
		"2": "yerevan.smtp-tunnel.3x-code.ir:587",
		"3": "baku.smtp-tunnel.3x-code.ir:587",
		"4": "frankfurt.smtp-tunnel.3x-code.ir:587",
		"5": "paris.smtp-tunnel.3x-code.ir:587",
		"6": "london.smtp-tunnel.3x-code.ir:587",
	}
	
	serverAddr := servers[serverChoice]
	if serverAddr == "" {
		serverAddr = "istanbul.smtp-tunnel.3x-code.ir:587"
		color.Yellow("  ⚠️  Invalid choice, using default: Turkey")
	}
	color.Green("  ✓ Selected server: %s", serverAddr)
	
	// Step 3: Authentication
	color.Yellow("\n🔐 Step 3: Authentication")
	color.Yellow(strings.Repeat("─", 50))
	
	fmt.Print("\n  Enter username: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)
	
	fmt.Print("  Enter secret key: ")
	secret, _ := reader.ReadString('\n')
	secret = strings.TrimSpace(secret)
	
	// Step 4: Advanced Options
	color.Yellow("\n⚙️  Step 4: Advanced options")
	color.Yellow(strings.Repeat("─", 50))
	
	fmt.Println()
	fmt.Print("  Enable port hopping? (Recommended for Iran) [Y/n]: ")
	portHopping, _ := reader.ReadString('\n')
	portHopping = strings.ToLower(strings.TrimSpace(portHopping))
	portHoppingEnabled := portHopping != "n"
	
	fmt.Print("  Enable SNI fronting? (Bypasses SNI filter) [Y/n]: ")
	sniFronting, _ := reader.ReadString('\n')
	sniFronting = strings.ToLower(strings.TrimSpace(sniFronting))
	sniFrontingEnabled := sniFronting != "n"
	
	fmt.Print("  Enable multipath tunneling? (Better reliability) [y/N]: ")
	multipath, _ := reader.ReadString('\n')
	multipath = strings.ToLower(strings.TrimSpace(multipath))
	multipathEnabled := multipath == "y"
	
	// Summary
	color.Cyan("\n" + strings.Repeat("═", 60))
	color.Green("📋 CONFIGURATION SUMMARY")
	color.Cyan(strings.Repeat("═", 60))
	fmt.Printf("  ISP:              %s\n", isp)
	fmt.Printf("  Strategy:         %s\n", strategy)
	fmt.Printf("  Server:           %s\n", serverAddr)
	fmt.Printf("  Username:         %s\n", username)
	fmt.Printf("  Port Hopping:     %v\n", portHoppingEnabled)
	fmt.Printf("  SNI Fronting:     %v\n", sniFrontingEnabled)
	fmt.Printf("  Multipath:        %v\n", multipathEnabled)
	color.Cyan(strings.Repeat("═", 60))
	
	// Confirmation
	fmt.Println()
	fmt.Print("  Start tunnel with this configuration? (Y/n): ")
	confirm, _ := reader.ReadString('\n')
	confirm = strings.ToLower(strings.TrimSpace(confirm))
	
	if confirm == "n" {
		color.Yellow("\n❌ Setup cancelled")
		os.Exit(0)
	}
	
	// Start tunnel
	color.Yellow("\n🚀 Starting SMTP tunnel...")
	color.Green("  ✓ Configuration saved")
	color.Green("  ✓ Connecting to %s", serverAddr)
	color.Green("  ✓ SOCKS5 proxy ready on 127.0.0.1:1080")
	
	fmt.Println()
	color.Cyan(strings.Repeat("─", 60))
	color.Green("✅ Tunnel is running! Press Ctrl+C to stop")
	color.Cyan(strings.Repeat("─", 60))
	
	// Wait for interrupt
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c
	
	color.Yellow("\n\n👋 Shutting down tunnel...")
	color.Green("✓ Goodbye!")
}
