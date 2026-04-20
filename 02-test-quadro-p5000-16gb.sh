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
# DECIZIE: P5000 SKIP per cerinta utilizatorului. Pe Vast.ai nu exista niciun GPU Pascal cu
# 16GB care sa fie LOWER BOUND - toate alternativele (P40 24GB, P100 16GB HBM2, 1080 Ti 11GB)
# sunt mai puternice macar pe o dimensiune (compute / bandwidth / VRAM) -> rezultate optimiste.
# Scriptul ramane ca placeholder. Daca P5000 apare vreodata pe Vast, se poate rula cu el.
ACCEPTED_GPU_REGEXES=("Quadro P5000")
PROXY_NOTE=""

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
