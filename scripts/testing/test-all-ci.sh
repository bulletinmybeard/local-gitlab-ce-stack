#!/bin/bash

echo "Testing all CI jobs..."
echo "====================="

echo ""
echo "1. Shell Script Validation..."
act push -W .github/workflows/ci-local.yml -j shell-check --container-architecture linux/amd64 2>&1 | grep -E "(Success|Failure|Job succeeded|Job failed)" | tail -5

echo ""
echo "2. Docker Validation..."
act push -W .github/workflows/ci-local.yml -j docker-check --container-architecture linux/amd64 2>&1 | grep -E "(Success|Failure|Job succeeded|Job failed)" | tail -5

echo ""
echo "3. YAML Validation..."
act push -W .github/workflows/ci-local.yml -j yaml-check --container-architecture linux/amd64 2>&1 | grep -E "(Success|Failure|Job succeeded|Job failed)" | tail -5

echo ""
echo "All tests completed!"
