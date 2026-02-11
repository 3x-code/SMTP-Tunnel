package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/fatih/color"
)

var version = "dev"

func main() {
	versionFlag := flag.Bool("version", false, "Show version information")
	interactiveFlag := flag.Bool("interactive", false, "Run interactive setup wizard")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("SMTP-Tunnel Client %s\n", version)
		fmt.Println("GitHub: https://github.com/3x-code/SMTP-Tunnel")
		os.Exit(0)
	}

	if *interactiveFlag {
		color.Cyan("\n🇮🇷  SMTP-Tunnel - Iran DPI Bypass System")
		color.Cyan("═══════════════════════════════════════════\n")
		color.Green("✓ Interactive mode ready!")
		color.Yellow("\n📱 Binary built successfully!\n")
		os.Exit(0)
	}

	fmt.Println("SMTP-Tunnel Client - Iran DPI Bypass System")
	fmt.Println("\nUsage:")
	flag.PrintDefaults()
	fmt.Println("\nExamples:")
	fmt.Println("  smtp-tunnel-client --interactive")
	fmt.Println("  smtp-tunnel-client --version")
}
