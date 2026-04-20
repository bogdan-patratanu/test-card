#!/usr/bin/env bash
# =============================================================================
# 02-test-quadro-p5000-16gb.sh - benchmark Quadro P5000 16GB
# Target: Quadro P5000 (Pascal GP104, 16GB GDDR5X, 288 GB/s, 8.9 TFLOPS)
# Pe Vast.ai NU exista P5000 -> surogat preferat: Tesla P40 24GB (Pascal GP102)
#                              -> alternativa: GTX 1080 Ti 11GB (warning OOM la 14B Q8)
# Rezultatele in proxy_mode = LOWER BOUND (P5000 reala >= proxy)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

GPU_KEY="quadro_p5000_16gb"
TARGET_GPU="Quadro P5000 16GB"
TARGET_VRAM_GB=16
# Ordinea conteaza: prima e target-ul real, restul sunt surogati
ACCEPTED_GPU_REGEXES=("Quadro P5000" "Tesla P40" "GTX 1080 Ti")
PROXY_NOTE="P5000 nu e pe Vast.ai. Surogat preferat: Tesla P40 24GB (Pascal, bandwidth similar). Atentie: rezultatele = lower bound, P5000 reala va fi mai lenta marginal."

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
