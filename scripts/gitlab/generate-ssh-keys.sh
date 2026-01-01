#!/bin/bash
# Script to generate SSH keys for GitLab if they don't exist

set -e

SSH_DIR="docker/gitlab"
PRIVATE_KEY="$SSH_DIR/local-gitlab"
PUBLIC_KEY="$SSH_DIR/local-gitlab.pub"

if [ -f "$PRIVATE_KEY" ]; then
    echo "SSH keys already exist"
else
    echo "Generating new SSH key pair..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N "" -C "admin@gitlab.local" > /dev/null 2>&1
    chmod 600 "$PRIVATE_KEY"
    chmod 644 "$PUBLIC_KEY"
    echo "SSH keys generated at $SSH_DIR/"
fi

# Verify/fix permissions silently
if [ -f "$PRIVATE_KEY" ]; then
    chmod 600 "$PRIVATE_KEY" 2>/dev/null || true
fi
