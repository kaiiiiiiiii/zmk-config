#!/usr/bin/env bash
set -euo pipefail

# GitHub Actions Self-hosted Runner Setup Script
# This script helps configure the Docker Compose environment for a GitHub Actions runner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-kaiiiiiiiii}"
REPO_NAME="${GITHUB_REPOSITORY:-zmk-config}"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"

echo "=== GitHub Actions Self-Hosted Runner Setup ==="
echo

# Check if Docker Compose is available
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose is not available"
    echo "Please ensure Docker Compose is installed (it's included with Docker Desktop)"
    exit 1
fi

echo "✓ Docker and Docker Compose are available"
echo

# Check current directory
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at: $COMPOSE_FILE"
    echo "Please run this script from the project root or ensure docker-compose.yml exists"
    exit 1
fi

echo "✓ Found docker-compose.yml"
echo

echo "Setting up GitHub Actions self-hosted runner for ${REPO_URL}"
echo

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) is required but not installed."
    echo "   Please install it from: https://cli.github.com/"
    exit 1
fi

echo "🔑 Getting runner registration token..."
if ! gh auth status >/dev/null 2>&1; then
    echo "Please authenticate with GitHub CLI first:"
    gh auth login
fi

# Get a new registration token
echo "Fetching registration token from GitHub..."
TOKEN_RESPONSE=$(gh api -X POST "/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token")
RUNNER_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token')

if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
    echo "❌ Failed to get runner registration token"
    echo "   Make sure you have admin access to the repository"
    exit 1
fi

echo "✅ Got registration token"

# Update docker-compose.yml
echo "📝 Updating docker-compose.yml with new token..."

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in current directory"
    exit 1
fi

# Create a backup
cp docker-compose.yml docker-compose.yml.bak
echo "📋 Backup created: docker-compose.yml.bak"

# Update the token in docker-compose.yml
sed -i "s/RUNNER_TOKEN: .*/RUNNER_TOKEN: ${RUNNER_TOKEN}/" docker-compose.yml

echo "✅ Updated docker-compose.yml with new registration token"
echo

# Verify Docker volumes and setup
echo "🔍 Verifying Docker setup..."

# Check if volumes exist and show their info
echo "Docker volumes that will be created/used:"
echo "• nix_store        - Nix package cache (critical for build performance)"
echo "• nix_root_profile - Root user Nix profile persistence"
echo "• actions_cache    - GitHub Actions cache"
echo "• build_cache      - Build artifacts cache"
echo

# Offer to start the runner
read -p "Would you like to start the GitHub Actions runner now? (y/N): " -r start_runner
if [[ $start_runner =~ ^[Yy]$ ]]; then
    echo "🚀 Starting GitHub Actions runner..."
    docker compose up -d
    
    echo
    echo "✅ Runner started! Monitor it with:"
    echo "   docker compose logs -f worker"
    echo
    echo "� Check runner status:"
    echo "   docker compose ps"
    echo
    echo "The runner should appear in your GitHub repository's Actions > Runners page shortly."
else
    echo "�🚀 Ready to start the runner:"
    echo "   docker compose up -d"
fi

echo
echo "📋 Troubleshooting tips:"
echo "• If builds fail with Nix errors, the persistent volumes will retain cached packages"
echo "• Check logs: docker compose logs worker"
echo "• Restart runner: docker compose restart worker"
echo "• Clean restart: docker compose down && docker compose up -d"
echo
echo "📊 Monitor the runner:"
echo "   docker compose logs -f worker"
echo
echo "🛑 Stop the runner:"
echo "   docker compose down"
echo
echo "ℹ️  The token is valid for 1 hour. Re-run this script to get a new one if needed."
echo "🔧 For Nix build issues, check the workflow logs in your GitHub repository."
