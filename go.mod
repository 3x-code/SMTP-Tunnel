cat > go.mod << 'EOF'
module github.com/3x-code/SMTP-Tunnel

go 1.21

require (
    github.com/fatih/color v1.18.0
)
EOF

go mod tidy
