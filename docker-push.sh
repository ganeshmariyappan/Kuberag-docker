set -euo pipefail

REGISTRY="${1:-docker.io/myorg}"
TAG="${2:-v1.0.0}"
SKIP_BUILD="${3:-}"

AGENT_IMAGE="${REGISTRY}/kuberag-agent:${TAG}"
PIPELINE_IMAGE="${REGISTRY}/kuberag-pipeline:${TAG}"

AGENT_LATEST="${REGISTRY}/kuberag-agent:latest"
PIPELINE_LATEST="${REGISTRY}/kuberag-pipeline:latest"
log()  { echo -e "\033[1;34m▶  $*\033[0m"; }
ok()   { echo -e "\033[1;32m✅ $*\033[0m"; }
err()  { echo -e "\033[1;31m❌ $*\033[0m" >&2; exit 1; }
warn() { echo -e "\033[1;33m⚠️  $*\033[0m"; }

banner() {
  echo ""
  echo "════════════════════════════════════════════"
  echo "  KubeRAG — Docker Push"
  echo "  Registry : ${REGISTRY}"
  echo "  Tag      : ${TAG}"
  echo "════════════════════════════════════════════"
  echo ""
}

preflight() {
  log "Running pre-flight checks..."

  command -v docker &>/dev/null || err "Docker not found. Install Docker first."

  docker info &>/dev/null || err "Docker daemon is not running."

  local registry_host
  registry_host=$(echo "${REGISTRY}" | cut -d'/' -f1)

  if [[ "${registry_host}" == "docker.io" ]] || [[ "${registry_host}" == *"."* ]]; then
    if ! docker system info 2>/dev/null | grep -q "Username"; then
      warn "You may not be logged in to ${registry_host}."
      warn "Run: docker login ${registry_host}"
    fi
  fi

  ok "Pre-flight checks passed."
}

build_images() {
  if [[ "${SKIP_BUILD}" == "--skip-build" ]]; then
    warn "Skipping build (--skip-build flag set)."
    return
  fi

  if docker buildx version &>/dev/null; then
    log "Building multi-arch images (linux/amd64, linux/arm64) with buildx..."

  
    docker buildx inspect kuberag-builder &>/dev/null \
      || docker buildx create --name kuberag-builder --use

    log "Building Agent image → ${AGENT_IMAGE}"
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --tag "${AGENT_IMAGE}" \
      --tag "${AGENT_LATEST}" \
      --file agent/Dockerfile \
      --push \
      agent/
    ok "Agent image built & pushed: ${AGENT_IMAGE}"

    log "Building Pipeline image → ${PIPELINE_IMAGE}"
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --tag "${PIPELINE_IMAGE}" \
      --tag "${PIPELINE_LATEST}" \
      --file data_pipeline/Dockerfile \
      --push \
      data_pipeline/
    ok "Pipeline image built & pushed: ${PIPELINE_IMAGE}"

    ALREADY_PUSHED=true

  else
    warn "docker buildx not available — building single-arch (linux/amd64)."
    ALREADY_PUSHED=false

    log "Building Agent image → ${AGENT_IMAGE}"
    docker build \
      --tag "${AGENT_IMAGE}" \
      --tag "${AGENT_LATEST}" \
      --file agent/Dockerfile \
      agent/
    ok "Agent image built: ${AGENT_IMAGE}"

    log "Building Pipeline image → ${PIPELINE_IMAGE}"
    docker build \
      --tag "${PIPELINE_IMAGE}" \
      --tag "${PIPELINE_LATEST}" \
      --file data_pipeline/Dockerfile \
      data_pipeline/
    ok "Pipeline image built: ${PIPELINE_IMAGE}"

push_images() {
  if [[ "${ALREADY_PUSHED:-false}" == "true" ]]; then
    log "Images already pushed via buildx --push. Skipping separate push step."
    return
  fi

  log "Pushing Agent image → ${AGENT_IMAGE}"
  docker push "${AGENT_IMAGE}"
  docker push "${AGENT_LATEST}"
  ok "Agent pushed: ${AGENT_IMAGE}"

  log "Pushing Pipeline image → ${PIPELINE_IMAGE}"
  docker push "${PIPELINE_IMAGE}"
  docker push "${PIPELINE_LATEST}"
  ok "Pipeline pushed: ${PIPELINE_IMAGE}"
}

verify_images() {
  log "Verifying pushed images via docker manifest inspect..."

  docker manifest inspect "${AGENT_IMAGE}"    &>/dev/null \
    && ok "Verified: ${AGENT_IMAGE}" \
    || warn "Could not verify ${AGENT_IMAGE} — check your registry."

  docker manifest inspect "${PIPELINE_IMAGE}" &>/dev/null \
    && ok "Verified: ${PIPELINE_IMAGE}" \
    || warn "Could not verify ${PIPELINE_IMAGE} — check your registry."
}

summary() {
  echo ""
  echo "════════════════════════════════════════════"
  echo "  ✅  Push Complete!"
  echo ""
  echo "  Agent    : ${AGENT_IMAGE}"
  echo "  Pipeline : ${PIPELINE_IMAGE}"
  echo ""
  echo "  Update your Helm values.yaml:"
  echo ""
  echo "  images:"
  echo "    agent:"
  echo "      repository: ${REGISTRY}/kuberag-agent"
  echo "      tag: ${TAG}"
  echo "    pipeline:"
  echo "      repository: ${REGISTRY}/kuberag-pipeline"
  echo "      tag: ${TAG}"
  echo ""
  echo "  Then deploy:"
  echo "  helm upgrade --install kuberag ./KubeRag -f values.yaml"
  echo "════════════════════════════════════════════"
}

main() {
  banner
  preflight
  build_images
  push_images
  verify_images
  summary
}

main
