#!/usr/bin/env bash
# =============================================================================
# run.sh - SINGURUL entry-point pentru benchmark pe Vast.ai
# Detecteaza GPU-ul cu nvidia-smi si invoca scriptul potrivit.
# =============================================================================
#
# Workflow pe instanta Vast (zero setup):
#   git clone https://github.com/<USER>/<REPO>.git
#   cd <REPO>/test-card
#   ./run.sh
#
# run.sh face:
#   1. Detecteaza GPU (nvidia-smi)
#   2. Mapeaza la scriptul corect (_common/gpu_mapping.sh)
#   3. Invoca scriptul (install Ollama + benchmark + git push results)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

# Colorat doar daca avem terminal
if [[ -t 1 ]]; then
    C_R=$'\e[0;31m'; C_G=$'\e[0;32m'; C_Y=$'\e[1;33m'
    C_C=$'\e[0;36m'; C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
    C_R=""; C_G=""; C_Y=""; C_C=""; C_BOLD=""; C_RESET=""
fi

echo "${C_C}=====================================================${C_RESET}"
echo "${C_C} VAST.AI GPU BENCHMARK - auto-dispatch${C_RESET}"
echo "${C_C}=====================================================${C_RESET}"
echo

# Verificari prealabile
if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "${C_R}[EROARE]${C_RESET} nvidia-smi nu e disponibil. Verifica ca instanta are GPU NVIDIA cu drivere instalate."
    exit 1
fi

if [[ ! -f _common/gpu_mapping.sh ]]; then
    echo "${C_R}[EROARE]${C_RESET} Lipseste _common/gpu_mapping.sh. Esti in directorul test-card?"
    exit 1
fi

source _common/gpu_mapping.sh

# Detecteaza primul GPU
DETECTED=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1 | xargs)
echo "${C_BOLD}GPU detectat:${C_RESET} $DETECTED"
echo

# Avertisment daca sunt mai multe GPU-uri (scriptul testeaza doar primul)
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | wc -l)
if (( GPU_COUNT > 1 )); then
    echo "${C_Y}[WARN]${C_RESET} Detectate $GPU_COUNT GPU-uri. Scriptul testeaza doar primul ($DETECTED)."
    echo
fi

# Mapeaza la script
SCRIPT=$(map_gpu_to_script "$DETECTED" || echo "")
if [[ -z "$SCRIPT" ]]; then
    echo "${C_R}[EROARE]${C_RESET} GPU '$DETECTED' nu e in lista de mapping."
    echo
    echo "GPU-uri suportate (vezi _common/gpu_mapping.sh):"
    list_supported_gpus
    echo
    echo "Daca vrei sa adaugi suport pentru acest GPU:"
    echo "  1. Editeaza _common/gpu_mapping.sh si adauga regex-ul potrivit"
    echo "  2. Daca e un GPU nou (nu surogat), creeaza un script test-<gpu>.sh"
    exit 1
fi

if [[ ! -x "./$SCRIPT" ]]; then
    echo "${C_R}[EROARE]${C_RESET} Scriptul $SCRIPT nu exista sau nu e executabil."
    echo "Incercand chmod +x..."
    chmod +x "./$SCRIPT" 2>/dev/null || true
    if [[ ! -x "./$SCRIPT" ]]; then
        echo "${C_R}[EROARE]${C_RESET} Nu pot face $SCRIPT executabil."
        exit 1
    fi
fi

echo "${C_G}[OK]${C_RESET} Mapping: $DETECTED -> ${C_BOLD}$SCRIPT${C_RESET}"
echo "${C_G}[OK]${C_RESET} Invoc scriptul..."
echo

exec "./$SCRIPT"
