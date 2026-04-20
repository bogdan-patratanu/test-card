#!/usr/bin/env bash
# =============================================================================
# 08-test-v100-32gb.sh - benchmark Tesla V100 32GB
# Target principal cerut. Volta GV100, 32GB HBM2, 900 GB/s, 14 TFLOPS FP32, 112 TFLOPS Tensor.
# Pret OLX Snagov ~$860 (server card, necesita racire externa).
# Regex strict pentru "V100.*32" pentru a respinge V100 16GB (alta poveste).
# Modele care vor rula: toate 6 (la fel ca RTX 3090, V100 32GB nu adauga modele noi)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

GPU_KEY="v100_32gb"
TARGET_GPU="Tesla V100 32GB"
TARGET_VRAM_GB=32
ACCEPTED_GPU_REGEXES=("V100.*32")
PROXY_NOTE=""

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
