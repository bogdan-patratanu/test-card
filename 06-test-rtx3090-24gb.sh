#!/usr/bin/env bash
# =============================================================================
# 06-test-rtx3090-24gb.sh - benchmark RTX 3090 24GB
# Target: RTX 3090 (Ampere GA102, 24GB GDDR6X, 936 GB/s, 35.6 TFLOPS FP32)
# Pret OLX Bucuresti ~$760 - cel mai bun deal raport pret/perf descoperit in cercetare.
# Modele care vor rula: 14B Q8, 32B Q3, 32B Q4, R1-14B, R1-32B, QwQ-32B (toate 6)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

GPU_KEY="rtx3090_24gb"
TARGET_GPU="RTX 3090 24GB"
TARGET_VRAM_GB=24
ACCEPTED_GPU_REGEXES=("RTX 3090")
PROXY_NOTE=""

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
