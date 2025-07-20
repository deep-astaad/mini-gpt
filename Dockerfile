## UNIVERSAL PYTHON 3.12 BASE & COMMON ASSETS

ARG PYTHON_VERSION=3.12
ARG APP_NAME=mini-gpt

# Stage with official Python (source of /usr/local tree we will copy elsewhere)
FROM python:${PYTHON_VERSION}-slim-bookworm AS py312-base
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
