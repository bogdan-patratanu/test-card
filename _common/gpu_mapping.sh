# =============================================================================
# gpu_mapping.sh - Mapare regex nvidia-smi -> nume_script
# Folosit de run.sh pentru auto-detect si dispatch.
# =============================================================================

# Format: "regex@@@script_filename" (separator @@@ pentru a nu intra in conflict cu | din regex)
# Ordinea conteaza: prima potrivire castiga.
GPU_MAPPINGS=(
    "RTX 5060 Ti@@@01-test-rtx5060ti-16gb.sh"
    # P5000 ca TARGET e SKIP. Daca apare pe Vast, o folosim ca surogat pentru RTX 5000 (mai jos).
    "Quadro RTX 5000@@@03-test-quadro-rtx5000-16gb.sh"
    "Tesla T4@@@03-test-quadro-rtx5000-16gb.sh"
    "Quadro P5000@@@03-test-quadro-rtx5000-16gb.sh"
    "NVIDIA A2($| )@@@03-test-quadro-rtx5000-16gb.sh"
    "RTX A2000@@@03-test-quadro-rtx5000-16gb.sh"
    "RTX A4000@@@03-test-quadro-rtx5000-16gb.sh"
    # Surogati pentru RTX 5000:
    #   LOWER 16GB: T4 (~73%) > P5000 (~70%) > A2 (~45%)
    #   LOWER 12GB: A2000 12GB (~70% perf, dar VRAM mai mic -> doar 1 model R1-14B)
    #   OPTIMIST 16GB: A4000 (~120%) - aplica corectie -15..-25% mental
    "RTX 3090@@@06-test-rtx3090-24gb.sh"
    "V100.*32@@@08-test-v100-32gb.sh"
)

# Returneaza scriptul corespunzator unui nume de GPU sau gol daca nu match
map_gpu_to_script() {
    local gpu_name="$1"
    local mapping
    for mapping in "${GPU_MAPPINGS[@]}"; do
        local pattern="${mapping%%@@@*}"
        local script="${mapping##*@@@}"
        if [[ "$gpu_name" =~ $pattern ]]; then
            echo "$script"
            return 0
        fi
    done
    return 1
}

# =============================================================================
# canonical_gpu_slug - Normalizeaza nume nvidia-smi + VRAM intr-un slug consistent
# folosit ca dirname in results/. Asa fiecare GPU REAL pe care a rulat are
# directorul lui (nu acoperit de target). Pe target real, slug-ul = GPU_KEY.
# Pe surogat, slug-ul = canonical pentru hardware-ul real.
# =============================================================================
canonical_gpu_slug() {
    local detected="$1"
    local vram_gb="$2"

    case "$detected" in
        # Target-uri exacte ale celor 5 placi cumparabile -> match GPU_KEY pentru consistenta backwards
        *"V100"*32*|*"V100-SXM2-32GB"*|*"V100-PCIE-32GB"*) echo "v100_32gb"               ;;
        *"V100"*16*|*"V100-SXM2-16GB"*|*"V100-PCIE-16GB"*) echo "v100_16gb"               ;;
        *"RTX 5060 Ti"*)                                   echo "rtx5060ti_16gb"          ;;
        *"RTX 3090"*)                                      echo "rtx3090_24gb"            ;;
        *"Quadro RTX 5000"*)                               echo "quadro_rtx5000_16gb"     ;;
        *"Quadro P5000"*)                                  echo "quadro_p5000_16gb"       ;;

        # Surogati comuni
        *"Tesla T4"*)                                      echo "tesla_t4_16gb"           ;;
        *"NVIDIA A2 "*|"NVIDIA A2")                        echo "nvidia_a2_16gb"          ;;
        *"Quadro RTX 6000"*)                               echo "quadro_rtx6000_24gb"     ;;
        *"RTX 2080 Ti"*)                                   echo "rtx2080ti_11gb"          ;;
        *"Titan RTX"*)                                     echo "titan_rtx_24gb"          ;;
        *"Tesla P40"*)                                     echo "tesla_p40_24gb"          ;;
        *"Tesla P100"*)                                    echo "tesla_p100_16gb"         ;;
        *"GTX 1080 Ti"*)                                   echo "gtx1080ti_11gb"          ;;
        *"RTX A2000"*)                                     echo "rtx_a2000_${vram_gb}gb"  ;;
        *"RTX A4000"*)                                     echo "rtx_a4000_16gb"          ;;
        *"RTX A5000"*)                                     echo "rtx_a5000_24gb"          ;;
        *"RTX A6000"*)                                     echo "rtx_a6000_48gb"          ;;
        *"RTX 4090"*)                                      echo "rtx4090_24gb"            ;;
        *"L4"*)                                            echo "l4_24gb"                 ;;

        # Fallback: slugify nume + vram
        *)
            local s
            s=$(echo "$detected" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g')
            echo "${s}_${vram_gb}gb"
            ;;
    esac
}

# =============================================================================
# Mapping informativ "actual_slug -> for_target_key" (cine-pentru-cine, fallback
# daca summary.json[target_gpu] lipseste). compare-results.sh foloseste ASTA
# DOAR ca fallback - sursa de adevar e summary.json scris la fiecare run.
# =============================================================================
SURROGATE_FOR=(
    "tesla_t4_16gb|quadro_rtx5000_16gb"
    "quadro_p5000_16gb|quadro_rtx5000_16gb"     # P5000 nu se mai testeaza ca target -> doar ca surogat
    "nvidia_a2_16gb|quadro_rtx5000_16gb"
    "rtx_a2000_12gb|quadro_rtx5000_16gb"        # LOWER perf, dar VRAM 12GB -> doar 1 model
    "rtx_a4000_16gb|quadro_rtx5000_16gb"        # OPTIMIST surogat: ~120% perf vs RTX 5000
)

# Returneaza target_key pentru un actual_slug, sau gol
surrogate_target_for() {
    local slug="$1"
    local m
    for m in "${SURROGATE_FOR[@]}"; do
        [[ "${m%%|*}" == "$slug" ]] && echo "${m##*|}" && return 0
    done
    return 1
}

# Listeaza toate GPU-urile suportate (pentru mesaj de eroare)
list_supported_gpus() {
    local mapping
    local seen=""
    for mapping in "${GPU_MAPPINGS[@]}"; do
        local pattern="${mapping%%@@@*}"
        local script="${mapping##*@@@}"
        if [[ ":$seen:" != *":$script:"* ]]; then
            echo "  - $pattern  -> $script"
            seen="$seen:$script"
        else
            echo "  - $pattern  -> $script (alias / surogat)"
        fi
    done
}
