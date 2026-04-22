# =============================================================================
# model_tiers.sh - Mapare VRAM_GB -> lista modele rulabile + KV cache size
# =============================================================================
#
# Format intrare ALL_MODELS:
#   modelfile_name|custom_name|base_model|model_size_mb|kv_per_token_kb_q8|min_vram_gb
#
# Camp explicat:
#   model_size_mb       = marimea modelului pe disc/VRAM (din `ollama show`)
#   kv_per_token_kb_q8  = bytes per token in KV cache la quantization q8_0
#                         Calculat din arhitectura: layers * 2 * num_kv_heads *
#                         head_dim (1 byte/value @ q8_0).
#   min_vram_gb         = pragul minim absolut sub care nici prompt mic nu intra
#                         (model_size + safety margin)
#
# Arhitecturi cunoscute (din Qwen 2.5 / DeepSeek-R1 distilled):
#   Qwen 7B:   28 layers,  4 KV heads (GQA), 128 head_dim ->  28 KB/tok @ q8_0
#   Qwen 14B:  48 layers,  8 KV heads (GQA), 128 head_dim ->  96 KB/tok @ q8_0
#   Qwen 32B:  64 layers,  8 KV heads (GQA), 128 head_dim -> 128 KB/tok @ q8_0
#   QwQ 32B:   identic cu Qwen 32B
#   R1 14B/32B distilled: identic cu Qwen 14B/32B
#
# IMPORTANT: min_vram_gb e gandit sa garanteze ca modelul ruleaza cu PROMPT-UL
# de ~35K tokens (nu doar ca incape modelul). Calculat ca:
#   model_size_mb + (35K + 2K buffer) * kv_kb_per_tok * 1.5 (overshoot) + safety
#
# Strategia adaugata: avem si modele MICI ca sa toate placile (16/24/32GB) sa
# poata rula cel putin acelasi model -> permite comparatie same-model intre carduri.
# =============================================================================

ALL_MODELS=(
    # modelfile         |custom_name  |base_model                          |model_size_mb |kv_kb_per_tok |min_vram_gb
    #
    # min_vram_gb = ceil(model_size_mb + 37251_tok * kv_kb/1024 + 768_safety) / 1024
    # 37251 = PROMPT(35203) + RESPONSE_BUFFER(2048) - vezi config.sh
    #
    # SAFETY NET - ruleaza GARANTAT pe orice placa 6GB+, baseline universal pt comparatie:
    "Modelfile-3b       |mss-3b       |qwen2.5:3b-instruct-q8_0            | 3800         | 28           |  6"
    #
    # MODELE MICI - ruleaza pe TOATE placile (12GB+) cu prompt-ul de 35K.
    # Esentiale pentru comparatia same-model intre carduri (16GB vs 24GB vs 32GB):
    "Modelfile-7b       |mss-7b       |qwen2.5:7b-instruct-q8_0            | 8500         | 28           | 11"
    "Modelfile-14b-q4   |mss-14b-q4   |qwen2.5:14b-instruct-q4_K_M         | 9500         | 96           | 15"
    #
    # MODELE 14B Q4 R1 - merge pe 16GB strans dar mai safe pe 24GB+:
    "Modelfile-r1-14b   |mss-r1-14b   |deepseek-r1:14b                     |12000         | 96           | 18"
    #
    # MODELE 14B Q8 FULL - cer 24GB:
    "Modelfile-14b      |mss-14b      |qwen2.5:14b-instruct-q8_0           |18000         | 96           | 23"
    #
    # MODELE 32B - cer 24GB+ (chiar q3 e strans):
    "Modelfile-32b-q3   |mss-32b-q3   |qwen2.5:32b-instruct-q3_K_S         |17000         |128           | 23"
    "Modelfile-32b-q4   |mss-32b-q4   |qwen2.5:32b-instruct-q4_K_M         |17500         |128           | 23"
    "Modelfile-r1-32b   |mss-r1-32b   |deepseek-r1:32b                     |17500         |128           | 23"
    "Modelfile-qwq-32b  |mss-qwq-32b  |qwq:32b                             |17500         |128           | 23"
)

# Returneaza modelele care intra macar la pragul minim de VRAM al GPU-ului dat.
# Filtru permisiv: vrem ca CALCULATORUL adaptive sa decida final daca incape
# cu prompt-ul actual. Aici doar excludem modele care clar nu intra in GPU.
# Output: o linie per model, format "modelfile|custom_name|base|size_mb|kv_kb|min_vram_gb"
select_models_for_vram() {
    local target_vram_gb="$1"
    local model
    for model in "${ALL_MODELS[@]}"; do
        local clean
        clean=$(echo "$model" | sed 's/[[:space:]]*|[[:space:]]*/|/g; s/^[[:space:]]*//; s/[[:space:]]*$//')
        local min_vram="${clean##*|}"
        if (( min_vram <= target_vram_gb )); then
            echo "$clean"
        fi
    done
}

# Calculeaza max ctx care incape pentru un (model, gpu) dat.
# Args: model_size_mb, kv_kb_per_tok, total_vram_mb, safety_margin_mb
# Stdout: max_ctx (rotunjit la multiplu de 1024)
compute_max_ctx() {
    local model_size_mb="$1"
    local kv_kb_per_tok="$2"
    local total_vram_mb="$3"
    local safety_margin_mb="$4"

    local free_for_kv_mb=$(( total_vram_mb - model_size_mb - safety_margin_mb ))
    if (( free_for_kv_mb <= 0 )); then
        echo 0
        return
    fi

    # max_ctx_tokens = (free_for_kv_mb * 1024) / kv_kb_per_tok
    local max_ctx=$(( (free_for_kv_mb * 1024) / kv_kb_per_tok ))

    # Round down to multiple of 1024
    max_ctx=$(( (max_ctx / 1024) * 1024 ))

    if (( max_ctx < 0 )); then max_ctx=0; fi
    echo $max_ctx
}
