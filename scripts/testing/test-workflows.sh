#!/bin/bash
# Script to test GitHub workflows locally using act

set -e

echo "Testing GitHub Workflows with act"
echo "================================"

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo "act is not installed. Please install it first:"
    echo "   brew install act"
    exit 1
fi

# Function to run a workflow
run_workflow() {
    local workflow=$1
    local event=${2:-push}
    local job=${3:-}
    echo ""
    echo "Testing: $workflow (event: $event${job:+, job: $job})"
    echo "-----------------------------------"

    if [ -n "$job" ]; then
        act $event -W ".github/workflows/$workflow" -j "$job" --container-architecture linux/amd64
    elif [ "$event" = "workflow_dispatch" ]; then
        act workflow_dispatch -W ".github/workflows/$workflow" --container-architecture linux/amd64
    else
        act $event -W ".github/workflows/$workflow" --container-architecture linux/amd64
    fi
}

echo "Testing local CI workflow..."
echo ""
echo "   a) Shell script validation..."
run_workflow "ci.yml" "push" "shell-check"

echo ""
echo "   b) Docker validation..."
run_workflow "ci.yml" "push" "docker-check"

echo ""
echo "   c) YAML validation..."
run_workflow "ci.yml" "push" "yaml-check"

echo ""
echo "All workflow tests completed!"
echo ""
echo "To test a specific job:"
echo "  act -W .github/workflows/ci.yml -j <job-name>"
echo ""
echo "To run all jobs:"
echo "  act -W .github/workflows/ci.yml"
