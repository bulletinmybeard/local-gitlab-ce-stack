#!/bin/bash

echo "Checking if GitLab SSH is available..."
for i in {1..12}; do
  if ssh-keyscan -t ed25519 -p 2222 localhost 2>/dev/null | grep -q ssh-ed25519; then
    echo "GitLab SSH is ready"
    break
  fi
  if [ $i -eq 12 ]; then
    echo "Warning: GitLab SSH might not be ready yet, continuing anyway..."
  else
    echo "Waiting for GitLab SSH... (attempt $i/12)"
    sleep 5
  fi
done

echo "Updating ~/.ssh/known_hosts..."
ssh-keygen -R "[localhost]:2222" > /dev/null 2>&1 || true
ssh-keygen -R gitlab.localhost > /dev/null 2>&1 || true
ssh-keyscan -t ed25519 -p 2222 localhost >> ~/.ssh/known_hosts 2>/dev/null
ssh-keyscan -t ed25519 -p 2222 -H gitlab.localhost >> ~/.ssh/known_hosts 2>/dev/null

PRIVATE_KEY="$(dirname "$0")/../local-gitlab"
if [ ! -f "$PRIVATE_KEY" ]; then
  echo "ERROR: Private key not found at $PRIVATE_KEY"
  echo "Please run ./scripts/gitlab/generate-ssh-keys.sh first"
  exit 1
fi

if [ ! -f ~/.ssh/gitlab-local ]; then
  cp "$PRIVATE_KEY" ~/.ssh/gitlab-local
  chmod 600 ~/.ssh/gitlab-local
  echo "SSH key copied to ~/.ssh/gitlab-local"
else
  if ! cmp -s "$PRIVATE_KEY" ~/.ssh/gitlab-local; then
    cp "$PRIVATE_KEY" ~/.ssh/gitlab-local
    chmod 600 ~/.ssh/gitlab-local
    echo "SSH key updated at ~/.ssh/gitlab-local"
  else
    echo "SSH key already up to date"
  fi
fi

if [ -f ~/.ssh/config ]; then
  # Remove existing GitLab entries silently
  sed -i.tmp '/^Host localhost$/,/^$/d' ~/.ssh/config 2>/dev/null || \
  sed -i '' '/^Host localhost$/,/^$/d' ~/.ssh/config 2>/dev/null || true
  sed -i.tmp '/^Host gitlab.localhost$/,/^$/d' ~/.ssh/config 2>/dev/null || \
  sed -i '' '/^Host gitlab.localhost$/,/^$/d' ~/.ssh/config 2>/dev/null || true
  rm -f ~/.ssh/config.tmp
fi

echo "Adding GitLab SSH config..."
cat >> ~/.ssh/config << 'EOF'

Host localhost gitlab.localhost gitlab-local
  HostName localhost
  User git
  Port 2222
  IdentityFile ~/.ssh/gitlab-local
  StrictHostKeyChecking no
  IdentitiesOnly yes

EOF

# Add key to ssh-agent if running
if [ -n "$SSH_AUTH_SOCK" ]; then
  ssh-add ~/.ssh/gitlab-local 2>/dev/null && echo "SSH key added to agent" || true
fi

echo "SSH client setup complete"
