#!/bin/bash
# Script to clean up GitLab Docker setup
# Usage: ./clean-gitlab-setup.sh [--traefik|-t] [--force|-f]

set -e

USE_TRAEFIK=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --traefik|-t)
            USE_TRAEFIK=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo "This script will clean up the GitLab Docker setup for a fresh start."
echo ""
echo "It will remove:"
echo "  - Docker containers"
echo "  - Docker volumes"
echo "  - Saved credentials and tokens"
echo "  - GitLab Runner configurations"
echo "  - SSH keys (gitlab-root, local-gitlab)"
echo "  - All generated YAML/TOML files"
echo "  - Initialization flag"
echo "  - Backup files (*.bak)"
if [ "$USE_TRAEFIK" = true ]; then
    echo "  - Traefik container and volumes"
fi
echo ""
if [ "$FORCE" = true ]; then
    REPLY="y"
else
    read -p "Continue? (y/N) " -n 1 -r
    echo ""
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ "$USE_TRAEFIK" = true ]; then
        echo "Stopping GitLab (Traefik mode) and removing volumes..."
        docker compose -f docker-compose.gitlab.yml down -v 2>/dev/null || true
        echo "Stopping Traefik and removing volumes..."
        docker compose -f docker-compose.traefik.yml down -v 2>/dev/null || true
    else
        echo "Stopping containers and removing volumes..."
        docker compose down -v 2>/dev/null || true
    fi

    echo "Removing external runner-config volume..."
    docker volume rm runner-config 2>/dev/null || true

    echo "Removing any remaining GitLab-related volumes..."
    docker volume ls -q 2>/dev/null | grep -E "gitlab|runner" | xargs -r docker volume rm 2>/dev/null || true

    echo "Removing credentials and initialization flag..."
    rm -f docker/gitlab/scripts/credentials.env
    rm -f docker/gitlab/scripts/credentials.yml
    rm -f docker/gitlab/scripts/.initialized

    echo "Removing GitLab Runner generated files..."
    rm -f docker/gitlab-runner/.runner_system_id
    rm -f docker/gitlab-runner/runner-config.toml
    rm -rf docker/gitlab-runner/config.toml/

    echo "Removing all generated config files with tokens..."
    find docker/gitlab-runner -name "*.toml" -type f ! -name "*.example" -delete 2>/dev/null || true
    find docker/gitlab-runner -name "*.yml" -type f ! -name "*.example" -delete 2>/dev/null || true
    find docker/gitlab-runner -name "*.yaml" -type f ! -name "*.example" -delete 2>/dev/null || true
    find docker/gitlab/scripts -name "*.yml" -type f ! -name "*.example" -delete 2>/dev/null || true
    find docker/gitlab/scripts -name "*.yaml" -type f ! -name "*.example" -delete 2>/dev/null || true

    echo "Removing SSH keys (if they exist)..."
    rm -f docker/gitlab/gitlab-root
    rm -f docker/gitlab/local-gitlab

    echo "Removing backup files..."
    find . -name "*.bak" -type f -delete 2>/dev/null || true

    echo ""
    echo "Verifying cleanup..."
    REMAINING_VOLUMES=$(docker volume ls -q 2>/dev/null | grep -E "gitlab|runner" || true)
    REMAINING_CONTAINERS=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E "gitlab|runner" || true)

    if [ -n "$REMAINING_VOLUMES" ] || [ -n "$REMAINING_CONTAINERS" ]; then
        echo "WARNING: Some resources may still exist:"
        [ -n "$REMAINING_VOLUMES" ] && echo "  Volumes: $REMAINING_VOLUMES"
        [ -n "$REMAINING_CONTAINERS" ] && echo "  Containers: $REMAINING_CONTAINERS"
        echo ""
        echo "You may need to remove these manually or stop other services using them."
    else
        echo "All GitLab resources removed successfully."
    fi

    echo ""
    echo "Cleanup complete! You can now run './scripts/gitlab/start-gitlab.sh' for a fresh start."
else
    echo "Cleanup cancelled."
fi
