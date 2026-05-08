#!/bin/bash
# ─────────────────────────────────────────────────────────────
# KubeRAG Docker — Git repo initializer & GitHub pusher
# Usage: ./git-setup.sh <github-username> <repo-name>
# Example: ./git-setup.sh myusername kuberag-docker
# ─────────────────────────────────────────────────────────────

set -euo pipefail

GITHUB_USERNAME="${1:-YOUR_USERNAME}"
REPO_NAME="${2:-kuberag-docker}"
GITHUB_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

log()  { echo -e "\033[1;34m▶  $*\033[0m"; }
ok()   { echo -e "\033[1;32m✅ $*\033[0m"; }
err()  { echo -e "\033[1;31m❌ $*\033[0m" >&2; exit 1; }

echo ""
echo "════════════════════════════════════════════"
echo "  KubeRAG Docker — Git Setup"
echo "  GitHub : ${GITHUB_URL}"
echo "════════════════════════════════════════════"
echo ""

# Pre-flight
command -v git &>/dev/null || err "git not found."

# ── Step 1: Init git repo ─────────────────────────────────────
log "Initializing git repository..."
git init
git checkout -b main
ok "Git repo initialized on branch: main"

# ── Step 2: Stage all files ───────────────────────────────────
log "Staging all files..."
git add .
git status
ok "Files staged."

# ── Step 3: Initial commit ────────────────────────────────────
log "Creating initial commit..."
git commit -m "feat: initial KubeRAG Docker images setup

- agent/Dockerfile        : FastAPI RAG chat service (multi-stage, non-root)
- agent/requirements.txt  : Agent Python dependencies
- data_pipeline/Dockerfile: FastAPI ingestion service (OCR + embedding)
- data_pipeline/requirements.txt: Pipeline Python dependencies
- docker-build.sh         : Local multi-arch build script
- docker-push.sh          : Build + tag + push script with registry support
- .github/workflows/docker-publish.yml: CI/CD auto build & push on tag/main
- README.md               : Full usage guide"

ok "Initial commit created."

# ── Step 4: Add remote ────────────────────────────────────────
log "Adding GitHub remote: ${GITHUB_URL}"
git remote add origin "${GITHUB_URL}"
ok "Remote added."

# ── Step 5: Push ──────────────────────────────────────────────
log "Pushing to GitHub..."
echo ""
echo "  ⚠️  Make sure you have created the repo on GitHub first:"
echo "  👉 https://github.com/new"
echo "  Repo name : ${REPO_NAME}"
echo "  Visibility: Public or Private"
echo ""
read -rp "Press ENTER when the GitHub repo is created..."

git push -u origin main
ok "Code pushed to: ${GITHUB_URL}"

# ── Step 6: Tag first version ────────────────────────────────
log "Tagging v1.0.0..."
git tag -a v1.0.0 -m "release: v1.0.0 — initial KubeRAG Docker images"
git push origin v1.0.0
ok "Tag v1.0.0 pushed — GitHub Actions CI/CD will trigger automatically!"

# ── Step 7: Set GitHub Secrets reminder ──────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "  ✅  Repo pushed successfully!"
echo ""
echo "  🔐  Add these GitHub Secrets to enable CI/CD:"
echo "  👉  ${GITHUB_URL%%.git}/settings/secrets/actions"
echo ""
echo "  Secret Name       Value"
echo "  ──────────────────────────────────────────"
echo "  DOCKER_USERNAME   your Docker Hub username"
echo "  DOCKER_PASSWORD   your Docker Hub access token"
echo ""
echo "  📦  After secrets are set, push any tag to trigger a build:"
echo "  git tag v1.0.1 && git push origin v1.0.1"
echo "════════════════════════════════════════════"
