#!/bin/bash
# Script to stop GitLab
# Usage: ./stop-gitlab.sh [--traefik|-t]

USE_TRAEFIK=false

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

if [ "$USE_TRAEFIK" = true ]; then
    echo "Stopping GitLab (Traefik mode)..."
    docker compose -f docker-compose.gitlab.yml down
    echo "Stopping Traefik..."
    docker compose -f docker-compose.traefik.yml down
else
    echo "Stopping GitLab..."
    docker compose down
fi

echo "GitLab stopped"
