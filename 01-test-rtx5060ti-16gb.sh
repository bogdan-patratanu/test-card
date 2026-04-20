#!/usr/bin/env bash
# =============================================================================
# 01-test-rtx5060ti-16gb.sh - benchmark RTX 5060 Ti 16GB pe Vast.ai
# Target: placa NOUA pe eMAG ~$696 (MSI Shadow 2X OC Plus)
# Modele care vor rula: 14B Q8, 32B Q3, R1-14B (3 modele, ~30-60 min)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

# Config GPU specific
GPU_KEY="rtx5060ti_16gb"
TARGET_GPU="RTX 5060 Ti 16GB"
TARGET_VRAM_GB=16
ACCEPTED_GPU_REGEXES=("RTX 5060 Ti")
PROXY_NOTE=""

# Source common libs (in ordine: config -> prices -> model_tiers -> lib)
source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
