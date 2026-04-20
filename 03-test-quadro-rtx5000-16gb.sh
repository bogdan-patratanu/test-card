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
# Surogati pentru RTX 5000 16GB (toate strict 16GB):
#   LOWER BOUND (RTX 5000 va fi mai rapida decat ce vezi):
#     1. Tesla T4 16GB     - TU104 Turing, ~73% perf (acelasi chip, downclocked) - IDEAL
#     2. Quadro P5000 16GB - GP104 Pascal, ~65-70% perf (strict lower pe ambele axe)
#     3. NVIDIA A2 16GB    - GA107 Ampere LP, ~45% perf (foarte conservator)
#   OPTIMIST (RTX 5000 va fi mai LENTA decat ce vezi - corectie -15..-25%):
#     4. RTX A4000 16GB    - GA104 Ampere, ~115-125% perf. Bandwidth identic 448 GB/s,
#                            dar 72% mai mult FP32 + tensor gen3 + arhitectura mai noua.
#                            Adaugata din necesitate (T4/P5000/A2 nu sunt disponibile).
ACCEPTED_GPU_REGEXES=("Quadro RTX 5000" "Tesla T4" "Quadro P5000" "NVIDIA A2" "RTX A4000")
PROXY_NOTE="RTX 5000 16GB (Turing TU104) nu e pe Vast.ai. Surogati: T4 (~73%, lower) > P5000 (~70%, lower) > A2 (~45%, lower) > A4000 (~120%, OPTIMIST). Daca rulezi pe A4000: RTX 5000 reala va fi cu ~15-25% MAI LENTA decat numerele masurate aici (corectie mentala obligatorie pentru decizia de cumparare)."

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
