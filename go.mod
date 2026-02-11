# 1. DELETE the corrupted go.mod file
rm -f go.mod

# 2. CREATE a brand new go.mod file with the CORRECT content
echo 'module github.com/3x-code/SMTP-Tunnel' > go.mod
echo '' >> go.mod
echo 'go 1.21' >> go.mod
echo '' >> go.mod
echo 'require (' >> go.mod
echo '    github.com/fatih/color v1.18.0' >> go.mod
echo ')' >> go.mod

# 3. VERIFY the file is correct
cat go.mod
