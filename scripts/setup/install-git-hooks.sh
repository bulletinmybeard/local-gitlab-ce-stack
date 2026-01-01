#!/bin/bash
# Install git hooks to prevent committing sensitive files

echo "Installing git pre-commit hook..."

# Create the pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook to prevent committing sensitive files

# Check for sensitive files
sensitive_files=$(git diff --cached --name-only | grep -E "(credentials\.env|runner-config\.toml|\.runner_system_id|local-gitlab$)" | grep -v "\.example")

if [ -n "$sensitive_files" ]; then
    echo "ERROR: Attempting to commit sensitive files:"
    echo "$sensitive_files"
    echo ""
    echo "These files contain auto-generated tokens or private keys and must not be committed."
    echo "Please remove them from your commit with: git reset HEAD <file>"
    exit 1
fi

# Check for any TOML/YAML files in sensitive directories
config_files=$(git diff --cached --name-only | grep -E "docker/gitlab-runner/.*\.(toml|yml|yaml)$|docker/gitlab/scripts/.*\.(yml|yaml)$" | grep -v "\.example")

if [ -n "$config_files" ]; then
    echo "WARNING: Attempting to commit configuration files that may contain tokens:"
    echo "$config_files"
    echo ""
    echo "Please verify these files do not contain any generated tokens before committing."
    echo "If they do, remove them with: git reset HEAD <file>"
    read -p "Are you sure these files are safe to commit? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

exit 0
EOF

chmod +x .git/hooks/pre-commit

echo "Git pre-commit hook installed successfully!"
echo ""
echo "This hook will prevent you from accidentally committing:"
echo "- Private SSH keys"
echo "- Generated credentials files"
echo "- Runner configuration with tokens"
echo "- Any auto-updated config files"
