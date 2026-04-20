#!/usr/bin/env bash
# =============================================================================
# 03-test-quadro-rtx5000-16gb.sh - benchmark Quadro RTX 5000 16GB
# Target: Quadro RTX 5000 (Turing TU104, 16GB GDDR6, 448 GB/s, 11.2 TFLOPS)
# Pe Vast.ai NU exista RTX 5000 -> surogat: Tesla T4 16GB (Turing TU104, acelasi chip)
# T4 = 8.1 TFLOPS si 320 GB/s -> RTX 5000 reala va fi cu ~30-40% mai rapida
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

GPU_KEY="quadro_rtx5000_16gb"
TARGET_GPU="Quadro RTX 5000 16GB"
TARGET_VRAM_GB=16
# Ordinea conteaza: prima e target real, restul sunt surogati
ACCEPTED_GPU_REGEXES=("Quadro RTX 5000" "Tesla T4")
PROXY_NOTE="RTX 5000 nu e pe Vast.ai. Surogat: Tesla T4 16GB (Turing TU104, mai slab pe toate dimensiunile). RTX 5000 reala va fi cu ~30-40% mai rapida."

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
