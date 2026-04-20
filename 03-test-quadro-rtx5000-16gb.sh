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
# Ordinea conteaza: prima e target real, restul sunt surogati Turing (in ordinea preferintei)
#   Tesla T4 16GB     - acelasi chip TU104, lower bound (preferred)
#   RTX 2080 Ti 11GB  - TU102 mai puternic dar 11GB -> 14B Q8 si 32B Q3 vor face OOM
#   Quadro RTX 6000   - TU102 24GB, OPTIMIST upper bound (toate 6 modele intra)
#   Titan RTX 24GB    - TU102 ca RTX 6000, optimist upper bound
ACCEPTED_GPU_REGEXES=("Quadro RTX 5000" "Tesla T4" "RTX 2080 Ti" "Quadro RTX 6000" "Titan RTX")
PROXY_NOTE="RTX 5000 16GB (Turing TU104) nu e pe Vast.ai. Surogati acceptati (in ordinea preferintei lower-bound): T4 16GB > 2080 Ti 11GB > RTX 6000 24GB > Titan RTX 24GB. Cu T4 -> rezultate lower bound. Cu RTX 6000/Titan -> rezultate OPTIMIST (RTX 5000 va fi mai lenta). Cu 2080 Ti -> doar R1-14B va incape (11GB)."

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
