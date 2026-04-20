# =============================================================================
# model_tiers.sh - Mapare VRAM_GB -> lista modele rulabile
# Returneaza array bash cu (modelfile_name|custom_name|base_model|approx_vram_gb)
# =============================================================================
#
# Modelele sunt definite o singura data. Functia select_models_for_vram filtreaza
# in functie de VRAM-ul GPU-ului target.
# =============================================================================

# Toate modelele disponibile, in ordine logica de rulare (rapide intai).
# min_vram_gb = pragul minim al placii (VRAM total) pentru care modelul incape
#               cu FlashAttention + KV cache q8_0 si num_ctx=32768.
# Valorile sunt CONSERVATIVE - daca pe Pascal (FA dezactivat) un model abia
# nu incape, scriptul il marcheaza OOM si trece la urmatorul (safe).
ALL_MODELS=(
    # modelfile           |custom_name      |base_model                         |min_vram_gb
    "Modelfile-r1-14b     |mss-r1-14b       |deepseek-r1:14b                    |10"
    "Modelfile-32b-q3     |mss-32b-q3       |qwen2.5:32b-instruct-q3_K_S        |15"
    "Modelfile-14b        |mss-14b          |qwen2.5:14b-instruct-q8_0          |15"
    "Modelfile-32b-q4     |mss-32b-q4       |qwen2.5:32b-instruct-q4_K_M        |19"
    "Modelfile-r1-32b     |mss-r1-32b       |deepseek-r1:32b                    |20"
    "Modelfile-qwq-32b    |mss-qwq-32b      |qwq:32b                            |20"
)

# Returneaza modelele care incap in VRAM-ul dat (in GB).
# Output: o linie per model, format "modelfile|custom_name|base_model|min_vram_gb"
select_models_for_vram() {
    local target_vram_gb="$1"
    local model
    for model in "${ALL_MODELS[@]}"; do
        # Cleanup whitespace in jurul de "|"
        local clean
        clean=$(echo "$model" | sed 's/[[:space:]]*|[[:space:]]*/|/g; s/^[[:space:]]*//; s/[[:space:]]*$//')
        local min_vram="${clean##*|}"
        if (( min_vram <= target_vram_gb )); then
            echo "$clean"
        fi
    done
}
