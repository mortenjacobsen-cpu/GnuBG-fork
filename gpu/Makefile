# Makefile for gnubg GPU engine
#
# Requirements:
#   - NVIDIA CUDA Toolkit (nvcc)
#   - GPU with compute capability >= 3.5
#
# Usage:
#   make                  Build gnubg-gpu binary
#   make clean            Remove build artifacts
#   make test             Quick smoke test (requires gnubg.wd)
#
# Configuration:
#   CUDA_PATH    Path to CUDA toolkit (default: /usr/local/cuda)
#   GPU_ARCH     GPU architecture (default: sm_70)
#   WEIGHT_FILE  Path to gnubg.wd for tests

# CUDA configuration
CUDA_PATH ?= /usr/local/cuda
NVCC      := $(CUDA_PATH)/bin/nvcc
GPU_ARCH  ?= sm_70

# Compiler flags
NVCC_FLAGS := -O3 \
              -arch=$(GPU_ARCH) \
              --use_fast_math \
              -Xcompiler -Wall \
              -Xcompiler -Wextra \
              -lineinfo

# For debugging:
# NVCC_FLAGS += -G -g -DGPU_DEBUG

# Link flags
LDFLAGS := -lcudart -lm

# Source files
KERNEL_SRC   := gnubg_gpu.cu
HOST_SRC     := gnubg_gpu_host.cu
MAIN_SRC     := gpu_main.c
HEADER       := gnubg_gpu.cuh
HOST_HEADER  := gnubg_gpu_host.h

# Object files
KERNEL_OBJ   := gnubg_gpu.o
HOST_OBJ     := gnubg_gpu_host.o
MAIN_OBJ     := gpu_main.o

# Output binary
TARGET := gnubg-gpu

# Default weight file location (for testing)
WEIGHT_FILE ?= ../gnubg.wd

# ============================================================

.PHONY: all clean test info

all: $(TARGET)

$(TARGET): $(KERNEL_OBJ) $(HOST_OBJ) $(MAIN_OBJ)
	$(NVCC) $(NVCC_FLAGS) -o $@ $^ $(LDFLAGS)
	@echo ""
	@echo "Build successful: $(TARGET)"
	@echo "Usage: ./$(TARGET) play -n 10000 -w /path/to/gnubg.wd"

$(KERNEL_OBJ): $(KERNEL_SRC) $(HEADER)
	$(NVCC) $(NVCC_FLAGS) -c -o $@ $(KERNEL_SRC)

$(HOST_OBJ): $(HOST_SRC) $(HEADER) $(HOST_HEADER)
	$(NVCC) $(NVCC_FLAGS) -c -o $@ $(HOST_SRC)

$(MAIN_OBJ): $(MAIN_SRC) $(HOST_HEADER)
	$(NVCC) $(NVCC_FLAGS) -x cu -c -o $@ $(MAIN_SRC)

clean:
	rm -f $(KERNEL_OBJ) $(HOST_OBJ) $(MAIN_OBJ) $(TARGET)

# Quick device info test (no weights needed)
info:
	@if [ -f $(TARGET) ]; then \
		./$(TARGET) info; \
	else \
		echo "Build first: make"; \
	fi

# Smoke test with 100 games
test: $(TARGET)
	@if [ ! -f $(WEIGHT_FILE) ]; then \
		echo "Weight file not found: $(WEIGHT_FILE)"; \
		echo "Set WEIGHT_FILE=/path/to/gnubg.wd"; \
		exit 1; \
	fi
	./$(TARGET) play -n 100 -w $(WEIGHT_FILE) -v
	@echo ""
	@echo "Smoke test passed."

# Full benchmark
bench: $(TARGET)
	@if [ ! -f $(WEIGHT_FILE) ]; then \
		echo "Weight file not found: $(WEIGHT_FILE)"; \
		exit 1; \
	fi
	./$(TARGET) bench -n 50000 -w $(WEIGHT_FILE)

# Print configuration
show-config:
	@echo "CUDA_PATH:   $(CUDA_PATH)"
	@echo "NVCC:        $(NVCC)"
	@echo "GPU_ARCH:    $(GPU_ARCH)"
	@echo "NVCC_FLAGS:  $(NVCC_FLAGS)"
	@echo "WEIGHT_FILE: $(WEIGHT_FILE)"
