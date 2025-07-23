## UNIVERSAL PYTHON 3.12 BASE & COMMON ASSETS

ARG PYTHON_VERSION=3.12
ARG APP_NAME=mini-gpt

# Stage with official Python (source of /usr/local tree we will copy elsewhere)
FROM python:${PYTHON_VERSION}-slim-bookworm AS py312-base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_CACHE_DIR=/root/.cache/uv \
    UV_PROJECT_ENVIRONMENT=/usr/local

# Install core build tooling only once here (reused when copied)
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

# Put project sources in their own stage so we can copy them to each build variant efficiently
FROM py312-base AS sources
WORKDIR /workspace
COPY pyproject.toml uv.lock* README.md ./
COPY src ./src

# Provide uv binary in its own stage for easy COPY (faster cache churn if uv updates)
FROM ghcr.io/astral-sh/uv:latest AS uv-bin


## BUILD VARIANTS

### CPU (and general dev) variant
FROM py312-base AS build-cpu
COPY --from=uv-bin /uv /uvx /bin/
WORKDIR /workspace
COPY --from=sources /workspace /workspace
RUN uv sync --extra cpu


### CUDA variant
# Use an NVIDIA runtime base for the CUDA user-space libs; copy Python 3.12 from py312-base; copy uv binary from uv-bin
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04 AS build-cuda

COPY --from=py312-base /usr/local /usr/local
COPY --from=uv-bin /uv /uvx /bin/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_CACHE_DIR=/root/.cache/uv \
    UV_PROJECT_ENVIRONMENT=/usr/local

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*
    
WORKDIR /workspace
COPY --from=sources /workspace /workspace
RUN uv sync --extra cu128


## RUNTIME STAGES

# Common runtime env variables
ARG APP_NAME=mini-gpt

FROM build-cpu AS runtime-cpu
ARG APP_NAME
ENV APP_VARIANT=cpu APP_NAME=${APP_NAME}
EXPOSE 8888
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["jupyter","lab","--ip=0.0.0.0","--no-browser","--port=8888"]

FROM build-cuda AS runtime-cuda
ARG APP_NAME
ENV APP_VARIANT=cuda APP_NAME=${APP_NAME}
EXPOSE 8888
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["jupyter","lab","--ip=0.0.0.0","--no-browser","--port=8888"]
