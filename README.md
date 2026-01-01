# GitLab Local Development Environment

[![GitLab CE](https://img.shields.io/badge/GitLab%20CE-18.7.0-FCA121?logo=gitlab)](https://about.gitlab.com/)
[![GitLab Runner](https://img.shields.io/badge/GitLab%20Runner-alpine3.21--511a9606-FCA121?logo=gitlab)](https://docs.gitlab.com/runner/)
[![Traefik](https://img.shields.io/badge/Traefik-3.6.5-24A1C1?logo=traefikproxy&logoColor=white)](https://traefik.io/)
[![Docker](https://img.shields.io/badge/Docker-20.10%2B-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-2.0%2B-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Docker Compose stack for running GitLab CE with GitLab Runner locally. Perfect for CI/CD experiments, testing GitLab features, and development workflows.

## Features

- **GitLab CE** - Full GitLab instance running locally
- **GitLab Runner** - Pre-configured with 4 runners (general, python, node, php)
- **Traefik Proxy** - Reverse proxy with HTTPS via mkcert
- **Automated initialization** - Group, projects, users, and runners created on first startup
- **Docker-in-Docker**: Full support for container builds in CI/CD
- **Optional HTTPS** - Traefik reverse proxy with mkcert certificates
- **SSH & HTTPS Access**: Both protocols configured out of the box

## Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Available Ports**: 8550 (HTTP), 443 (HTTPS), 2222 (SSH), 8080 (Traefik Dashboard), 9252 (metrics)
- **Memory**: Minimum 4GB RAM recommended
- **Storage**: At least 10GB free disk space

## Architecture

```text
┌──────────────────────────────────────────────────────┐
│                  Docker Network                      │
│          (gitlab-network: 172.31.0.0/16)             │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────────┐                             │
│  │   Traefik Proxy     │                             │
│  │   (172.31.0.10)     │                             │
│  │                     │                             │
│  │  - HTTP → HTTPS     │                             │
│  │  - Auto SSL/TLS     │                             │
│  │  - Load Balancing   │                             │
│  └──────────┬──────────┘                             │
│             │                                        │
│             ▼                                        │
│  ┌─────────────────────┐       ┌──────────────────┐  │
│  │   GitLab CE         │       │   GitLab Runner  │  │
│  │   (172.31.0.2)      │◄──────┤   (172.31.0.3)   │  │
│  │                     │       │                  │  │
│  │  - Web UI (80)      │       │  - 4 Runners:    │  │
│  │  - Git SSH (2222)   │       │    • General     │  │
│  │  - API              │       │    • Python 3.12 │  │
│  │  - 6 Demo Projects  │       │    • Node.js 20  │  │
│  │                     │       │    • PHP 8.2     │  │
│  └─────────────────────┘       └──────────────────┘  │
└──────────────────────────────────────────────────────┘
```

**Note**: The diagram shows the full architecture with Traefik. In standalone mode (default), only GitLab CE and GitLab Runner are started.

## Quick Start

### Clone and Setup

```bash
# Clone the repository
git clone https://github.com/bulletinmybeard/local-gitlab-ce-stack.git
cd local-gitlab-ce-stack

# Setup environment
cp .env.sample .env
# Edit .env and set GITLAB_ROOT_PASSWORD
```

### Start GitLab and GitLab Runner

```bash
./scripts/gitlab/start-gitlab.sh
```

First startup takes about 2-5 minutes. The script will:

- Create a Docker network
- Spin up GitLab CE and GitLab Runner containers
- Wait for services to be healthy
- Initialize demo projects and runners
- Configure SSH access

### Access GitLab

- **GitLab URL**: <http://localhost:8550>
- **SSH**: git@localhost:2222
- **Username**: root
- **Password**: Check your `.env` file
- **Demo User**: johndoe (password in `.env`)

## Usage Modes

The stack supports two modes of operation:

### Standalone Mode (Default)

Access GitLab via `http://localhost:8550` - no Traefik, no HTTPS. This is the simplest setup.

```bash
./scripts/gitlab/start-gitlab.sh
./scripts/gitlab/stop-gitlab.sh
./scripts/gitlab/clean-gitlab-setup.sh
```

### Traefik Mode (HTTPS)

Access GitLab via `https://gitlab.localhost` with Traefik reverse proxy and mkcert SSL certificates.

Requires additional setup - see [Traefik Configuration](#traefik-configuration) below.

```bash
./scripts/gitlab/start-gitlab.sh --traefik
./scripts/gitlab/stop-gitlab.sh --traefik
./scripts/gitlab/clean-gitlab-setup.sh --traefik
```

## Auto-Created Resources

### Projects (in `demo-group`)

- `python-test` - Python project template
- `php-test` - PHP project template
- `nodejs-test` - Node.js project template
- `ext-test` - External integration testing
- `int-test` - Internal integration testing
- `demo` - General demo project

### GitLab Runners

| Runner         | Tags                     | Docker Image   | Purpose               |
|:---------------|:-------------------------|:---------------|:----------------------|
| general-runner | docker, general, default | alpine:latest  | General purpose CI/CD |
| python-runner  | python, python3          | python:3.12    | Python applications   |
| node-runner    | node, nodejs             | node:20        | Node.js applications  |
| php-runner     | php, php8, laravel       | php:8.2-cli    | PHP applications      |

### Users

- **root** - Administrator account
- **johndoe** - Demo user with full access to demo-group

## Security

### Environment Variables

- `GITLAB_ROOT_PASSWORD` - Root user password
- `DEMO_USERNAME` - Demo user username
- `DEMO_USER_PASSWORD` - Demo user password

### SSH Access

SSH keys are automatically generated on first startup and copied to `~/.ssh/gitlab-local`. To regenerate keys, run `./scripts/gitlab/generate-ssh-keys.sh`.

## Troubleshooting

### GitLab Won't Start

```bash
# Check container status
docker ps -a

# View GitLab logs
docker logs gitlab

# Check GitLab health
docker exec gitlab gitlab-ctl status
```

### Can't Access Web UI

```bash
# Verify GitLab is healthy
docker inspect gitlab | grep -A5 Health

# Check if port 8550 is available
lsof -i :8550
```

### SSH Connection Refused

```bash
# Regenerate SSH client config
./docker/gitlab/scripts/setup-ssh-client.sh

# Test SSH connection
ssh -T -p 2222 git@localhost
```

### Reset Everything

```bash
# Stop and clean all resources
./scripts/gitlab/clean-gitlab-setup.sh

# This will remove:
# - All containers
# - Generated credentials
# - SSH configurations
# - Docker volumes
```

## Usage Examples

### Clone via SSH

SSH uses port 2222 to avoid conflicts with your system's SSH daemon:

```bash
# Using GIT_SSH_COMMAND to specify the port
GIT_SSH_COMMAND="ssh -p 2222" git clone git@localhost:demo-group/python-test.git

# Or configure SSH once in ~/.ssh/config (see below)
git clone git@gitlab-local:demo-group/python-test.git
```

**Tip**: Add this to `~/.ssh/config` for easier cloning:

```
Host gitlab-local
    HostName localhost
    Port 2222
    User git
    IdentityFile ~/.ssh/gitlab-local
```

### Clone via HTTP

```bash
# Using access token (recommended)
git clone http://root:${TOKEN}@localhost:8550/demo-group/python-test.git

# Using password
git clone http://root:${PASSWORD}@localhost:8550/demo-group/python-test.git
```

### Create CI/CD Pipeline

Create `.gitlab-ci.yml` in your project:

```yaml
stages:
  - test
  - build

test-python:
  stage: test
  tags:
    - python
  script:
    - python --version
    - pip install pytest
    - pytest

build-docker:
  stage: build
  tags:
    - docker
  script:
    - docker build -t myapp .
```

## Traefik Configuration

**Note**: This section only applies when using Traefik mode (`--traefik` flag).

### Overview

Traefik provides:

- Automatic HTTPS with locally trusted certificates
- Clean URLs (`https://gitlab.localhost`)
- Built-in dashboard for monitoring
- Load balancing and health checks

### Prerequisites

Add these entries to your `/etc/hosts` file:

```bash
127.0.0.1  gitlab.localhost
127.0.0.1  traefik.localhost
```

### SSL Certificate Setup

This project uses **mkcert** to generate locally trusted SSL certificates. This means no browser warnings!

#### Prerequisites

**Install mkcert first:**

```bash
# macOS
brew install mkcert
brew install nss # if you use Firefox

# Linux - download from https://github.com/FiloSottile/mkcert/releases
```

#### Generate Certificates

```bash
cd traefik-data/certs && ./setup-mkcert.sh
```

This will:

- Install the mkcert root CA in your system trust store
- Generate certificates for localhost, gitlab.localhost, traefik.localhost
- Make them trusted by your browser automatically

#### Regenerating Certificates

To regenerate certificates (e.g., after changing hostnames in .env):

```bash
rm -f traefik-data/certs/localhost.*
cd traefik-data/certs && ./setup-mkcert.sh
docker compose restart traefik-gitlab
```

### Traefik Dashboard

Access the Traefik dashboard at `https://traefik.localhost` to:

- View active routes and services
- Monitor health checks
- Debug routing issues
- View real-time metrics

## Links

- [Changelog](https://github.com/bulletinmybeard/local-gitlab-ce-stack/blob/master/CHANGELOG.md)

## License

MIT License - see the [LICENSE](https://github.com/bulletinmybeard/local-gitlab-ce-stack/blob/master/LICENSE) file for details.
