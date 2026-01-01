#!/bin/bash

apt-get update -qq && apt-get install -y -qq jq > /dev/null 2>&1

run_init_script() {
    if [ -f /opt/scripts/.initialized ]; then
        echo "GitLab already initialized, skipping..."
        return
    fi

    echo "Waiting for GitLab to become available..."
    while ! curl -s http://localhost/users/sign_in > /dev/null; do
        echo -n "."
        sleep 5
    done
    echo " Ready!"

    echo "Waiting for GitLab to stabilize..."
    sleep 30

    echo 'Running initialization script...'
    if /opt/scripts/init.sh; then
        echo 'Initialization completed successfully'
    else
        echo 'ERROR: init.sh failed to complete'
    fi
}

run_init_script &

# Start GitLab
exec /assets/init-container
