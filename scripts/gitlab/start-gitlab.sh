#!/bin/bash
# Script to start GitLab and automatically setup SSH access
# Usage: ./start-gitlab.sh [--traefik|-t]

set -e

USE_TRAEFIK=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --traefik|-t)
            USE_TRAEFIK=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "Error: .env file not found!"
    echo "Please copy .env.sample to .env and configure it."
    exit 1
fi

echo ""
echo "Starting GitLab Development Environment"
if [ "$USE_TRAEFIK" = true ]; then
    echo "(with Traefik reverse proxy)"
fi
echo ""

echo "Checking SSH keys..."
./scripts/gitlab/generate-ssh-keys.sh

# Only check/generate SSL certificates when using Traefik
if [ "$USE_TRAEFIK" = true ]; then
    if [ ! -f "./traefik-data/certs/localhost.crt" ] || [ ! -f "./traefik-data/certs/localhost.key" ]; then
        echo "SSL certificates not found, attempting to generate..."
        if command -v mkcert &> /dev/null; then
            echo "mkcert found, generating certificates..."
            (cd traefik-data/certs && ./setup-mkcert.sh)
        else
            echo ""
            echo "ERROR: SSL certificates not found and mkcert is not installed!"
            echo ""
            echo "Option 1: Install mkcert and retry"
            echo "  brew install mkcert  # macOS"
            echo "  mkcert -install"
            echo ""
            echo "Option 2: Generate certificates manually"
            echo "  cd traefik-data/certs && ./setup-mkcert.sh"
            exit 1
        fi
    else
        echo "SSL certificates found"
    fi
fi

echo ""
echo "Creating Docker network if not exists..."
docker network create gitlab-network 2>/dev/null || true

echo "Creating runner-config volume..."
docker volume create runner-config 2>/dev/null || true

# Check for stale state: volume exists but no initialized flag
GITLAB_VOLUME_EXISTS=$(docker volume ls -q | grep -E "gitlab.*data|local-gitlab-ce-stack_gitlab-data" || true)
INIT_FLAG="./docker/gitlab/scripts/.initialized"

if [ -n "$GITLAB_VOLUME_EXISTS" ] && [ ! -f "$INIT_FLAG" ]; then
    echo ""
    echo "WARNING: GitLab data volume exists but no initialization flag found."
    echo "This may indicate a partial cleanup that could cause encryption issues."
    echo ""
    read -p "Run full cleanup first? (Y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Running cleanup..."
        ./scripts/gitlab/clean-gitlab-setup.sh --force
        echo ""
        echo "Cleanup complete. Continuing with fresh start..."
        echo ""
        echo "Re-creating Docker network..."
        docker network create gitlab-network 2>/dev/null || true
        echo "Re-creating runner-config volume..."
        docker volume create runner-config 2>/dev/null || true
    fi
fi

# Start containers based on mode
if [ "$USE_TRAEFIK" = true ]; then
    echo ""
    echo "Starting Traefik..."
    docker compose -f docker-compose.traefik.yml up -d

    echo "Waiting for Traefik to be healthy..."
    while [ "$(docker inspect -f '{{.State.Health.Status}}' traefik-gitlab 2>/dev/null)" != "healthy" ]; do
        echo -n "."
        sleep 2
    done
    echo " Done"

    echo ""
    echo "Starting GitLab (Traefik mode)..."
    docker compose -f docker-compose.gitlab.yml up -d
else
    echo ""
    echo "Starting GitLab (standalone mode)..."
    docker compose up -d
fi

echo ""
echo "Waiting for GitLab to be healthy..."
while [ "$(docker inspect -f '{{.State.Health.Status}}' gitlab 2>/dev/null)" != "healthy" ]; do
    echo -n "."
    sleep 5
done
echo " Done"

echo ""
echo "Setting up SSH access..."
./docker/gitlab/scripts/setup-ssh-client.sh

echo ""
echo "Getting GitLab credentials..."
PASSWORD="${GITLAB_ROOT_PASSWORD}"

CREDS_FILE="./docker/gitlab/scripts/credentials.env"
INIT_FLAG="./docker/gitlab/scripts/.initialized"

if [ -f "$INIT_FLAG" ] && [ ! -f "$CREDS_FILE" ]; then
    echo ""
    echo "WARNING: Detected inconsistent state - .initialized exists but credentials.env is missing"
    echo "Removing .initialized flag to allow re-initialization..."
    rm -f "$INIT_FLAG"

    echo "Restarting GitLab container to trigger initialization..."
    docker restart gitlab > /dev/null

    echo "Waiting for GitLab to restart..."
    while [ "$(docker inspect -f '{{.State.Health.Status}}' gitlab 2>/dev/null)" != "healthy" ]; do
        echo -n "."
        sleep 5
    done
    echo " Done"
fi

echo "Waiting for GitLab to initialize and create credentials..."
echo "(This may take 1-2 minutes on first run)"
WAIT_TIME=0
MAX_WAIT=150

if [ -f "$CREDS_FILE" ]; then
    echo "Found existing credentials file"
else
    while [ ! -f "$CREDS_FILE" ] && [ $WAIT_TIME -lt $MAX_WAIT ]; do
        echo -n "."
        sleep 5
        WAIT_TIME=$((WAIT_TIME + 5))

        # Provide status update every 30 seconds
        if [ $((WAIT_TIME % 30)) -eq 0 ]; then
            echo -n " (${WAIT_TIME}s)"
        fi
    done
    echo ""
fi

if [ -f "$CREDS_FILE" ]; then
    echo "Credentials file ready"
    sleep 2
    # Source the credentials file to get the token
    source "$CREDS_FILE"
    TOKEN="${GITLAB_ACCESS_TOKEN:-}"
else
    echo ""
    echo "WARNING: credentials.env was not created within timeout period"
    echo "GitLab initialization might still be in progress"
    TOKEN="Not available yet - check GitLab container logs!"
fi

echo ""
echo "==========================================="
echo "  GitLab is ready!"
echo "==========================================="
echo ""
echo "Access Information:"
if [ "$USE_TRAEFIK" = true ]; then
    echo "   GitLab URL:        https://gitlab.localhost"
    echo "   Traefik Dashboard: https://traefik.localhost"
else
    echo "   GitLab URL:        http://localhost:8550"
fi
echo "   SSH:               git@localhost:2222"
echo "   Username:          root"
echo "   Password:          $PASSWORD"
echo "   Token:             $TOKEN"
echo ""
echo "Available Projects:"
echo "   - demo-group/python-test"
echo "   - demo-group/php-test"
echo "   - demo-group/nodejs-test"
echo "   - demo-group/ext-test"
echo "   - demo-group/int-test"
echo "   - demo-group/demo"
echo ""
if [ "$USE_TRAEFIK" = true ]; then
    echo "Note: You may need to add these entries to your /etc/hosts file:"
    echo "   127.0.0.1 gitlab.localhost"
    echo "   127.0.0.1 traefik.localhost"
    echo ""
fi
