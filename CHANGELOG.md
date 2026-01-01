# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-12-31

### Changed
- **Docker Images Updated**:
  - GitLab CE: 18.2.4 -> 18.7.0
  - GitLab Runner: alpine3.21-139fb059 -> alpine3.21-511a9606
- **Init script ported from Python to Bash** (`init.sh`) - No Python dependencies required (anymore)
- **Credentials format**: Changed from `credentials.yml` (YAML) to `credentials.env` (shell-sourceable)
- **Release workflow**: Updated to use release notes with Docker image versions

### Removed
- **All Python tooling removed**:
  - Config files: `.black`, `.flake8`, `.isort.cfg`, `mypy.ini`, `.python-version`
  - Dependencies: `requirements.txt`, `requirements-dev.txt`
  - Pre-commit: `.pre-commit-config.yaml`
- **Python scripts**:
  - `docker/gitlab/scripts/init.py` - Replaced by `init.sh`
  - `docker/gitlab/scripts/disable-telemetry.py` - Redundant (settings in docker-compose.yml)
- **Unused workflow files**:
  - `.github/workflows/test.yml`
  - `.github/markdown-link-check-config.json`

### Added
- `docker/gitlab/scripts/init.sh` - Bash initialization script using `curl` and `jq`
- `traefik-data/certs/setup-mkcert.sh` - SSL certificate generation script
- `traefik-data/certs/dynamic.yml` - Traefik TLS configuration
- `.env.sample` - Env var template

### Fixed
- Telemetry settings now configured via `GITLAB_OMNIBUS_CONFIG` in docker-compose.yml

## [1.0.0] - 2025-08-20

### Added
- **GitLab CE 18.2.4** - Full GitLab Community Edition instance
- **GitLab Runner** - Pre-configured with 4 runners (Docker, Shell, DinD, Python)
- **Traefik Proxy 3.2** - HTTPS with reverse proxy
- **SSL/TLS via mkcert** - Trusted local certificates
- **Auto-initialization** - Setting up root user, demo projects, tokens, and runners
- **SSH Key Management** - Automatic SSH key generation and configuration
- **Telemetry Disabled** - All usage tracking disabled
- **Git Hooks** - Pre-commit hooks to prevent committing sensitive data
- **Python 3.12 Support** - Full Python dev environment
- **Code Quality Tools** - Black, isort, Flake8, MyPy integration
- **CI/CD Testing** - GitHub Actions workflows with local testing via `act`
