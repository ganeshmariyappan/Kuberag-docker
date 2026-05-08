
set -euo pipefail

REGISTRY="${1:-localhost}"
TAG="${2:-v1.0.0}"

AGENT_IMAGE="${REGISTRY}/kuberag-agent:${TAG}"
PIPELINE_IMAGE="${REGISTRY}/kuberag-pipeline:${TAG}"

echo "========================================"
echo "  KubeRAG Docker Image Builder"
echo "  Registry : ${REGISTRY}"
echo "  Tag      : ${TAG}"
echo "========================================"


echo ""
echo "▶  Building Agent Service → ${AGENT_IMAGE}"
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${AGENT_IMAGE}" \
  --file agent/Dockerfile \
  agent/

echo "✅ Agent image built: ${AGENT_IMAGE}"


echo ""
echo "▶  Building Data Pipeline Service → ${PIPELINE_IMAGE}"
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${PIPELINE_IMAGE}" \
  --file data_pipeline/Dockerfile \
  data_pipeline/

echo "✅ Pipeline image built: ${PIPELINE_IMAGE}"

if [[ "${REGISTRY}" != "localhost" ]]; then
  echo ""
  echo "▶  Pushing images to ${REGISTRY} ..."
  docker push "${AGENT_IMAGE}"
  docker push "${PIPELINE_IMAGE}"
  echo "✅ Both images pushed."
else
  echo ""
  echo "ℹ️  Skipping push (registry is 'localhost')."
  echo "    Re-run with your registry to push:"
  echo "    ./docker-build.sh myregistry.io/kuberag v1.0.0"
fi

echo ""
echo "========================================"
echo "  Done!"
echo "  Agent    : ${AGENT_IMAGE}"
echo "  Pipeline : ${PIPELINE_IMAGE}"
echo "========================================"
