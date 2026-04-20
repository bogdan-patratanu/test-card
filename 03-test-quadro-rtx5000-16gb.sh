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
# Surogati valizi pentru RTX 5000 16GB (toate sunt strict 16GB si LOWER pe compute+bandwidth):
#   1. Tesla T4 16GB     - TU104 Turing, ~73% perf (acelasi chip, doar downclocked) - PREFERAT
#   2. Quadro P5000 16GB - GP104 Pascal, ~65-70% perf (strict lower pe ambele axe)
#   3. NVIDIA A2 16GB    - GA107 Ampere LP, ~45% perf (foarte conservator, lower bound generos)
# Toate produc rezultate LOWER BOUND -> RTX 5000 reala va fi mai rapida decat ce vezi.
# Restul GPU-urilor de pe Vast (RTX 2080 Ti, RTX 6000, Titan RTX, A4000, P100) sunt mai puternice
# pe macar o axa critica -> EXCLUSE (ar produce decizii optimiste).
ACCEPTED_GPU_REGEXES=("Quadro RTX 5000" "Tesla T4" "Quadro P5000" "NVIDIA A2")
PROXY_NOTE="RTX 5000 16GB (Turing TU104) nu e pe Vast.ai. Surogati lower-bound (in ordinea preferintei): T4 16GB (~73%) > P5000 16GB (~65-70%) > A2 16GB (~45%). RTX 5000 reala va fi mai rapida decat ce masori cu surogatul - cu cat folosesti unul mai slab, cu atat marja e mai mare."

source _common/config.sh
source _common/prices.sh
source _common/model_tiers.sh
source _common/lib.sh

main_pipeline
