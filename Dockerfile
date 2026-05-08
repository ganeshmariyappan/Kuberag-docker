# ─────────────────────────────────────────────────────────────
# KubeRAG — Agent Service Dockerfile
# FastAPI chat service: query processing, RAG logic, LLM calls
# ─────────────────────────────────────────────────────────────

# ── Stage 1: builder ──────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build tools only in this stage
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install dependencies first (layer-cache friendly)
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --prefix=/install --no-cache-dir -r requirements.txt


# ── Stage 2: runtime ─────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Metadata labels
LABEL maintainer="KubeRAG" \
      service="kuberag-agent" \
      version="1.0.0" \
      description="KubeRAG Agent Service – RAG chat API"

# Non-root user for security
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY app.py .
COPY agent.py .
COPY llm_providers.py .

# If you have a config/ or utils/ subdirectory, include it:
# COPY config/ ./config/

# Set ownership
RUN chown -R appuser:appgroup /app

# Runtime environment variables (override via K8s ConfigMap / Secret)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000 \
    # LLM provider: openai | azure_openai | anthropic | gemini | ollama
    LLM_PROVIDER=openai \
    OPENAI_API_KEY="" \
    AZURE_OPENAI_API_KEY="" \
    AZURE_OPENAI_ENDPOINT="" \
    AZURE_OPENAI_DEPLOYMENT="gpt-4o-mini" \
    ANTHROPIC_API_KEY="" \
    GOOGLE_API_KEY="" \
    OLLAMA_BASE_URL="http://ollama-service:11434" \
    # Vector store connection
    VECTOR_STORE_TYPE=qdrant \
    VECTOR_STORE_HOST=qdrant-service \
    VECTOR_STORE_PORT=6333 \
    VECTOR_STORE_COLLECTION_NAME=documents \
    VECTOR_STORE_DIMENSION=384 \
    # Embedding model (must match pipeline service)
    EMBEDDING_MODEL=all-MiniLM-L12-v2 \
    # Retrieval settings
    TOP_K_RESULTS=5 \
    SIMILARITY_THRESHOLD=0.7

# Expose FastAPI port
EXPOSE 8000

# Switch to non-root
USER appuser

# Health check – K8s readiness/liveness probe target
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Start FastAPI with uvicorn
CMD ["python", "-m", "uvicorn", "app:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2", \
     "--log-level", "info"]
