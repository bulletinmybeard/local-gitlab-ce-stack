#!/bin/bash
#
# GitLab initialization script
# Creates demo group, projects, users, and runners via GitLab API

set -euo pipefail

GITLAB_URL="http://localhost"
API_URL="${GITLAB_URL}/api/v4"
CREDENTIALS_FILE="/opt/scripts/credentials.env"
INITIALIZED_FLAG="/opt/scripts/.initialized"
SSH_KEY_PUB="/opt/local-gitlab.pub"

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - $1"; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $1" >&2; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN - $1"; }

ACCESS_TOKEN=""
GROUP_ID=""
ROOT_USER_ID=""
ROOT_EMAIL=""
DEMO_USER_ID=""
PERSONAL_ACCESS_TOKEN=""

# Runner configuration storage (shared volume with gitlab-runner container)
RUNNER_CONFIG_FILE="/opt/runner-config/config.toml"
declare -a RUNNER_CONFIGS=()

api_get() {
    local endpoint="$1"
    curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "${API_URL}/${endpoint}"
}

api_post() {
    local endpoint="$1"
    local data="$2"
    curl -s -X POST \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        "${API_URL}/${endpoint}" \
        -d "${data}"
}

api_post_form() {
    local endpoint="$1"
    shift
    curl -s -X POST \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "${API_URL}/${endpoint}" \
        "$@"
}

api_put() {
    local endpoint="$1"
    local data="$2"
    curl -s -X PUT \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        "${API_URL}/${endpoint}" \
        -d "${data}"
}

get_access_token() {
    log_info "Authenticating with GitLab..."

    if [ -z "${GITLAB_ROOT_PASSWORD:-}" ]; then
        log_error "GITLAB_ROOT_PASSWORD environment variable is not set"
        exit 1
    fi

    local response
    response=$(curl -s -X POST "${GITLAB_URL}/oauth/token" \
        -d "grant_type=password" \
        -d "username=root" \
        -d "password=${GITLAB_ROOT_PASSWORD}")

    ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token // empty')

    if [ -z "$ACCESS_TOKEN" ]; then
        log_error "Failed to get access token"
        log_error "Response: $response"
        exit 1
    fi

    log_info "Successfully authenticated"
}

get_user_info() {
    log_info "Getting user info..."
    local user_info
    user_info=$(api_get "user")

    ROOT_USER_ID=$(echo "$user_info" | jq -r '.id')
    ROOT_EMAIL=$(echo "$user_info" | jq -r '.email')

    log_info "User ID: $ROOT_USER_ID, Email: $ROOT_EMAIL"
}

create_group() {
    local name="$1"
    local path="$2"

    log_info "Creating group '$name'..."

    local existing
    existing=$(api_get "groups?search=${path}" | jq -r --arg path "$path" '.[] | select(.path == $path) | .id // empty')

    if [ -n "$existing" ]; then
        log_info "Group '$name' already exists (ID: $existing)"
        GROUP_ID="$existing"
        return
    fi

    local response
    response=$(api_post "groups" "$(cat <<EOF
{
    "name": "${name}",
    "path": "${path}",
    "description": "Demo group for testing",
    "auto_devops_enabled": true,
    "lfs_enabled": true,
    "project_creation_level": "maintainer",
    "visibility": "internal"
}
EOF
)")

    GROUP_ID=$(echo "$response" | jq -r '.id // empty')

    if [ -n "$GROUP_ID" ] && [ "$GROUP_ID" != "null" ]; then
        log_info "Created group '$name' (ID: $GROUP_ID)"
    else
        log_error "Failed to create group '$name'"
        log_error "Response: $response"
        exit 1
    fi
}

create_project() {
    local name="$1"
    local path="$2"
    local group_id="$3"

    local existing
    existing=$(api_get "projects?search=${path}" | jq -r --arg path "$path" '.[] | select(.path == $path) | .id // empty')

    if [ -n "$existing" ]; then
        log_info "Project '$name' already exists (ID: $existing)"
        return
    fi

    local response
    response=$(api_post "projects" "$(cat <<EOF
{
    "name": "${name}",
    "path": "${path}",
    "description": "Test project",
    "initialize_with_readme": true,
    "group_runners_enabled": true,
    "lfs_enabled": true,
    "shared_runners_enabled": true,
    "namespace_id": ${group_id}
}
EOF
)")

    local project_id
    project_id=$(echo "$response" | jq -r '.id // empty')

    if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
        log_info "Created project '$name' (ID: $project_id)"
    else
        log_error "Failed to create project '$name'"
        log_error "Response: $response"
    fi
}

create_demo_user() {
    local username="${DEMO_USERNAME:-}"
    local password="${DEMO_USER_PASSWORD:-}"

    if [ -z "$username" ] || [ -z "$password" ]; then
        log_warn "DEMO_USERNAME or DEMO_USER_PASSWORD not set, skipping demo user creation"
        return
    fi

    local email="${username}@example.com"

    log_info "Creating demo user '$username'..."

    local existing
    existing=$(api_get "users?search=${email}" | jq -r --arg email "$email" '.[] | select(.email == $email) | .id // empty')

    if [ -n "$existing" ]; then
        log_info "Demo user '$username' already exists (ID: $existing)"
        DEMO_USER_ID="$existing"
        return
    fi

    local response
    response=$(api_post "users" "$(cat <<EOF
{
    "username": "${username}",
    "name": "John Doe",
    "password": "${password}",
    "email": "${email}",
    "commit_email": "${email}",
    "admin": true,
    "auditor": true,
    "can_create_group": true,
    "skip_confirmation": true,
    "theme_id": 3
}
EOF
)")

    DEMO_USER_ID=$(echo "$response" | jq -r '.id // empty')

    if [ -n "$DEMO_USER_ID" ] && [ "$DEMO_USER_ID" != "null" ]; then
        log_info "Created demo user '$username' (ID: $DEMO_USER_ID)"
    else
        log_error "Failed to create demo user"
        log_error "Response: $response"
    fi
}

add_member_to_group() {
    local group_id="$1"
    local user_id="$2"
    local user_email="$3"

    if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
        return
    fi

    log_info "Adding user '$user_email' to group..."

    local response
    response=$(api_post_form "groups/${group_id}/members" \
        -d "user_id=${user_id}" \
        -d "access_level=50")

    local error
    error=$(echo "$response" | jq -r '.message // empty')

    if [ -n "$error" ]; then
        if echo "$error" | grep -qi "already"; then
            log_info "User '$user_email' is already a member of the group"
        else
            log_warn "Could not add user to group: $error"
        fi
    else
        log_info "Added user '$user_email' to group"
    fi
}

create_runner() {
    local name="$1"
    local tags="$2"
    local group_id="$3"
    local docker_image="$4"

    log_info "Creating runner '$name'..."

    local existing
    existing=$(api_get "runners" | jq -r --arg name "$name" '.[] | select(.description == $name) | .id // empty')

    if [ -n "$existing" ]; then
        log_info "Runner '$name' already exists (ID: $existing)"
        return
    fi

    local tags_json
    tags_json=$(echo "$tags" | jq -R 'split(",")')

    local response
    response=$(api_post "user/runners" "$(cat <<EOF
{
    "runner_type": "group_type",
    "group_id": ${group_id},
    "description": "${name}",
    "tag_list": ${tags_json},
    "run_untagged": true,
    "locked": false,
    "access_level": "not_protected"
}
EOF
)")

    local runner_id
    runner_id=$(echo "$response" | jq -r '.id // empty')
    local runner_token
    runner_token=$(echo "$response" | jq -r '.token // empty')

    if [ -n "$runner_id" ] && [ "$runner_id" != "null" ]; then
        log_info "Created runner '$name' (ID: $runner_id)"
        if [ -n "$runner_token" ] && [ "$runner_token" != "null" ]; then
            RUNNER_CONFIGS+=("${name}|${runner_token}|${docker_image}")
            log_info "Captured registration token for '$name'"
        else
            log_warn "No token returned for runner '$name'"
        fi
    else
        log_error "Failed to create runner '$name'"
        log_error "Response: $response"
    fi
}

setup_ssh_key() {
    local user_id="$1"
    local user_email="$2"

    if [ ! -f "$SSH_KEY_PUB" ]; then
        log_warn "SSH public key not found at $SSH_KEY_PUB, skipping"
        return
    fi

    log_info "Setting up SSH key for user '$user_email'..."

    local ssh_key
    ssh_key=$(cat "$SSH_KEY_PUB")

    local existing_keys
    existing_keys=$(api_get "users/${user_id}/keys")

    local key_exists
    key_exists=$(echo "$existing_keys" | jq -r --arg title "$user_email" '.[] | select(.title == $title) | .id // empty')

    if [ -n "$key_exists" ]; then
        log_info "SSH key for '$user_email' already exists"
        return
    fi

    local expires_at
    expires_at=$(date -d "+99 years" '+%Y-%m-%d' 2>/dev/null || date -v+99y '+%Y-%m-%d' 2>/dev/null || echo "2124-01-01")

    local response
    response=$(api_post "users/${user_id}/keys" "$(cat <<EOF
{
    "title": "${user_email}",
    "key": "${ssh_key}",
    "expires_at": "${expires_at}"
}
EOF
)")

    local key_id
    key_id=$(echo "$response" | jq -r '.id // empty')

    if [ -n "$key_id" ] && [ "$key_id" != "null" ]; then
        log_info "Added SSH key for '$user_email'"
    else
        log_warn "Could not add SSH key: $(echo "$response" | jq -r '.message // "unknown error"')"
    fi
}

create_personal_access_token() {
    local user_id="$1"

    log_info "Creating personal access token..."

    local token_name="Gitlab-CE-Local-Token-$(date '+%Y%m%d_%H%M%S')"
    local expires_at
    expires_at=$(date -d "+365 days" '+%Y-%m-%d' 2>/dev/null || date -v+365d '+%Y-%m-%d' 2>/dev/null || echo "2026-01-01")

    local response
    response=$(api_post_form "users/${user_id}/personal_access_tokens" \
        -d "name=${token_name}" \
        -d "scopes[]=api" \
        -d "expires_at=${expires_at}")

    PERSONAL_ACCESS_TOKEN=$(echo "$response" | jq -r '.token // empty')

    if [ -n "$PERSONAL_ACCESS_TOKEN" ] && [ "$PERSONAL_ACCESS_TOKEN" != "null" ]; then
        log_info "Created personal access token: ${token_name}"
    else
        log_warn "Could not create personal access token"
        PERSONAL_ACCESS_TOKEN=""
    fi
}

disable_signups() {
    log_info "Disabling user sign-ups..."

    local response
    response=$(api_put "application/settings" '{"signup_enabled": false}')

    local signup_enabled
    signup_enabled=$(echo "$response" | jq -r '.signup_enabled // empty')

    if [ "$signup_enabled" = "false" ]; then
        log_info "User sign-ups disabled"
    else
        log_warn "Could not verify sign-up settings: $(echo "$response" | jq -r '.message // "unknown"')"
    fi
}

generate_runner_config() {
    log_info "Generating runner configuration..."

    if [ ${#RUNNER_CONFIGS[@]} -eq 0 ]; then
        log_warn "No runner tokens captured, skipping config generation"
        return
    fi

    cat > "$RUNNER_CONFIG_FILE" <<EOF
concurrent = 4
check_interval = 3
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

EOF

    for config in "${RUNNER_CONFIGS[@]}"; do
        IFS='|' read -r name token image <<< "$config"
        cat >> "$RUNNER_CONFIG_FILE" <<EOF
[[runners]]
  name = "${name}"
  url = "http://gitlab"
  clone_url = "http://gitlab"
  token = "${token}"
  executor = "docker"
  [runners.docker]
    image = "${image}"
    helper_image = "gitlab/gitlab-runner-helper:arm64-v17.7.0"
    privileged = true
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
    network_mode = "gitlab-network"
    pull_policy = ["always"]

EOF
    done

    chmod 644 "$RUNNER_CONFIG_FILE"
    log_info "Runner configuration saved to $RUNNER_CONFIG_FILE with ${#RUNNER_CONFIGS[@]} runners"
}

save_credentials() {
    log_info "Saving credentials to $CREDENTIALS_FILE..."

    cat > "$CREDENTIALS_FILE" <<EOF
# GitLab credentials - generated by init.sh
# Source this file: source /opt/scripts/credentials.env

GITLAB_URL="${GITLAB_URL}"
GITLAB_GROUP_ID="${GROUP_ID}"
GITLAB_GROUP_NAME="demo-group"

GITLAB_ROOT_USER_ID="${ROOT_USER_ID}"
GITLAB_ROOT_EMAIL="${ROOT_EMAIL}"
GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD}"

GITLAB_ACCESS_TOKEN="${PERSONAL_ACCESS_TOKEN:-${ACCESS_TOKEN}}"

GITLAB_DEMO_USER_ID="${DEMO_USER_ID:-}"
GITLAB_DEMO_USERNAME="${DEMO_USERNAME:-}"
EOF

    chmod 600 "$CREDENTIALS_FILE"
    log_info "Credentials saved"
}

main() {
    log_info "Starting GitLab initialization..."

    if [ -f "$INITIALIZED_FLAG" ]; then
        log_info "GitLab already initialized, skipping"
        exit 0
    fi

    get_access_token
    get_user_info

    disable_signups

    create_group "Demo Group" "demo-group"

    local projects="python-test php-test nodejs-test ext-test int-test demo"
    for project in $projects; do
        create_project "$project" "$project" "$GROUP_ID"
    done

    setup_ssh_key "$ROOT_USER_ID" "$ROOT_EMAIL"

    create_personal_access_token "$ROOT_USER_ID"

    create_runner "general-runner" "docker,general,default" "$GROUP_ID" "alpine:latest"
    create_runner "python-runner" "python,python3" "$GROUP_ID" "python:3.12"
    create_runner "node-runner" "node,nodejs" "$GROUP_ID" "node:20"
    create_runner "php-runner" "php,php8,laravel" "$GROUP_ID" "php:8.2-cli"

    generate_runner_config

    create_demo_user
    if [ -n "$DEMO_USER_ID" ] && [ "$DEMO_USER_ID" != "null" ]; then
        add_member_to_group "$GROUP_ID" "$DEMO_USER_ID" "${DEMO_USERNAME}@example.com"
        setup_ssh_key "$DEMO_USER_ID" "${DEMO_USERNAME}@example.com"
    fi

    save_credentials

    touch "$INITIALIZED_FLAG"

    log_info "GitLab initialization completed successfully"
}

main "$@"
