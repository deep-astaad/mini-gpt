# ---------- Base w/ build tools ----------
FROM python:3.12-slim-bookworm AS build

# Install uv early (binary copy)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_CACHE_DIR=/root/.cache/uv \
    UV_PROJECT_ENVIRONMENT=/usr/local

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl build-essential git ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Leverage layer caching for deps
COPY pyproject.toml uv.lock* ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync

# Copy source
COPY src ./src
COPY README.md ./
# (Optional) Remove if not needed; uv already compiled packages
# RUN python -m compileall -q src

# ---------- Runtime ----------
FROM python:3.12-slim-bookworm AS runtime
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_CACHE_DIR=/root/.cache/uv \
    UV_PROJECT_ENVIRONMENT=/usr/local \
    HF_HOME=/workspace/.cache/huggingface \
    TRANSFORMERS_CACHE=/workspace/.cache/huggingface

# tini only (no build chain)
RUN apt-get update && apt-get install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy Python installation (packages + scripts)
# COPY --from=build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=build /usr/local /usr/local

# Copy project
COPY --from=build /workspace /workspace

# Ensure cache dirs exist & writable
RUN mkdir -p .cache/huggingface .jupyter

EXPOSE 8888
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--port=8888"]
