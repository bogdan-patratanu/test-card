# =============================================================================
# gpu_mapping.sh - Mapare regex nvidia-smi -> nume_script
# Folosit de run.sh pentru auto-detect si dispatch.
# =============================================================================

# Format: "regex|script_filename"
# Ordinea conteaza: prima potrivire castiga.
GPU_MAPPINGS=(
    "RTX 5060 Ti|01-test-rtx5060ti-16gb.sh"
    "Quadro P5000|02-test-quadro-p5000-16gb.sh"
    "Tesla P40|02-test-quadro-p5000-16gb.sh"
    "GTX 1080 Ti|02-test-quadro-p5000-16gb.sh"
    "Quadro RTX 5000|03-test-quadro-rtx5000-16gb.sh"
    "Tesla T4|03-test-quadro-rtx5000-16gb.sh"
    "RTX 3090|06-test-rtx3090-24gb.sh"
    "V100.*32|08-test-v100-32gb.sh"
)

# Returneaza scriptul corespunzator unui nume de GPU sau gol daca nu match
map_gpu_to_script() {
    local gpu_name="$1"
    local mapping
    for mapping in "${GPU_MAPPINGS[@]}"; do
        local pattern="${mapping%%|*}"
        local script="${mapping##*|}"
        if [[ "$gpu_name" =~ $pattern ]]; then
            echo "$script"
            return 0
        fi
    done
    return 1
}

# Listeaza toate GPU-urile suportate (pentru mesaj de eroare)
list_supported_gpus() {
    local mapping
    local seen=""
    for mapping in "${GPU_MAPPINGS[@]}"; do
        local pattern="${mapping%%|*}"
        local script="${mapping##*|}"
        if [[ ":$seen:" != *":$script:"* ]]; then
            echo "  - $pattern  -> $script"
            seen="$seen:$script"
        else
            echo "  - $pattern  -> $script (alias / surogat)"
        fi
    done
}
