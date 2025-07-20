# ==============================================
# Makefile for docker compose (cpu / cuda modes)
# ==============================================

# MODE can be: cpu (default) or cuda (gpu alias accepted)
MODE ?= cpu
ifeq ($(MODE),gpu)
MODE := cuda
endif
ifneq ($(MODE),cpu)
ifneq ($(MODE),cuda)
$(error MODE must be cpu or cuda (got '$(MODE)'))
endif
endif

PROFILE := $(MODE)

# Service names in your compose file
CPU_SERVICE  := dev-cpu
CUDA_SERVICE := dev-cuda
SERVICE := $(if $(filter $(MODE),cuda),$(CUDA_SERVICE),$(CPU_SERVICE))

COMPOSE ?= docker compose
FLAGS   ?=

# Detect nvidia-smi (host GPU presence)
HAS_NVIDIA := $(shell command -v nvidia-smi >/dev/null 2>&1 && echo 1 || echo 0)

# Colors (optional)
C_RESET  := \033[0m
C_GREEN  := \033[32m
C_YELLOW := \033[33m
C_CYAN   := \033[36m

# Simple banner macro (safe—just echo)
define banner
	@echo "$(C_CYAN)==> $(1)$(C_RESET)"
endef

# Shell-level GPU warning (no make conditionals embedded)
GPU_WARNING_CMD = if [ "$(MODE)" = "cuda" ] && [ "$(HAS_NVIDIA)" != "1" ]; then \
	echo "$(C_YELLOW)[WARN] Requested CUDA mode but 'nvidia-smi' not found on host. GPU may not be accessible.$(C_RESET)"; \
fi

.PHONY: build up down restart logs ps shell exec help

build:
	$(call banner,Building image for profile '$(PROFILE)' (service: $(SERVICE)))
	@$(GPU_WARNING_CMD)
	$(COMPOSE) --profile $(PROFILE) build $(SERVICE) $(FLAGS)

up:
	$(call banner,Starting profile '$(PROFILE)' (service: $(SERVICE)))
	@$(GPU_WARNING_CMD)
	$(COMPOSE) --profile $(PROFILE) up $(SERVICE) $(FLAGS)

down:
	$(call banner,Stopping all compose services)
	$(COMPOSE) down $(FLAGS)

restart: down up

logs:
	$(call banner,Following logs for '$(SERVICE)' (profile $(PROFILE)))
	$(COMPOSE) --profile $(PROFILE) logs -f $(SERVICE)

ps:
	$(call banner,Listing containers)
	$(COMPOSE) ps

shell:
	$(call banner,Opening shell in '$(SERVICE)' (profile $(PROFILE)))
	$(COMPOSE) --profile $(PROFILE) exec $(SERVICE) bash

exec:
ifndef CMD
	$(error Provide CMD="..." e.g. make exec CMD="python -c 'import torch;print(torch.cuda.is_available())'")
endif
	$(call banner,Executing in '$(SERVICE)': $(CMD))
	$(COMPOSE) --profile $(PROFILE) exec $(SERVICE) bash -lc "$(CMD)"

help:
	@echo ""
	@echo "$(C_GREEN)Make targets (current MODE=$(MODE))$(C_RESET)"
	@echo "  make build          MODE=cpu|cuda   Build the selected profile's service image"
	@echo "  make up             MODE=cpu|cuda   Start (foreground) selected profile"
	@echo "    Add FLAGS='-d' for detached mode (e.g. make up MODE=cuda FLAGS='-d')"
	@echo "  make down                           Stop all services"
	@echo "  make restart        MODE=cpu|cuda   Stop & start the selected profile"
	@echo "  make logs           MODE=cpu|cuda   Follow logs"
	@echo "  make ps                             List containers"
	@echo "  make shell          MODE=cpu|cuda   Open bash shell"
	@echo "  make exec CMD=...   MODE=cpu|cuda   Run arbitrary command"
	@echo "  make help                           Show this help"
	@echo ""
	@echo "Service mapping:"
	@echo "  cpu  -> $(CPU_SERVICE)"
	@echo "  cuda -> $(CUDA_SERVICE)"
	@echo ""
