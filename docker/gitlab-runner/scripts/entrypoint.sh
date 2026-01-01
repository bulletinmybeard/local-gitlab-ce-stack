#!/bin/sh

CONFIG_SOURCE="/opt/runner-config/config.toml"
CONFIG_DEST="/etc/gitlab-runner/config.toml"
MAX_WAIT=300

echo "Waiting for GitLab to be ready..."
until curl -sf http://gitlab/users/sign_in -o /dev/null; do
  echo "GitLab is not ready yet. Waiting..."
  sleep 10
done
echo "GitLab is ready!"

mkdir -p /etc/gitlab-runner

echo "Waiting for runner configuration from GitLab init..."
waited=0
while [ ! -f "$CONFIG_SOURCE" ] && [ $waited -lt $MAX_WAIT ]; do
  echo "Config not ready yet, waiting... ($waited/$MAX_WAIT seconds)"
  sleep 5
  waited=$((waited + 5))
done

if [ -f "$CONFIG_SOURCE" ]; then
  echo "Runner configuration found, copying to $CONFIG_DEST"
  cp "$CONFIG_SOURCE" "$CONFIG_DEST"
  echo "Configuration loaded:"
  grep -c "^\[\[runners\]\]" "$CONFIG_DEST" | xargs -I{} echo "  {} runner(s) configured"
else
  echo "WARNING: Runner configuration not found after ${MAX_WAIT}s"
  echo "Creating minimal config (runners will need manual registration)"
  cat > "$CONFIG_DEST" << 'EOF'
concurrent = 1
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800
EOF
fi

exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
