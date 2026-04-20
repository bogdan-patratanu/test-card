# =============================================================================
# lib.sh - Functii comune pentru toate scripturile de benchmark GPU.
# Sursa unica de logica. Scripturile per-GPU doar definesc variabilele si
# apeleaza main_pipeline.
# =============================================================================
#
# Variabile asteptate (definite in scriptul caller, INAINTE de source):
#   GPU_KEY                - cheie pentru lookup in prices.sh (ex: v100-32gb)
#   TARGET_GPU             - nume human readable (ex: "Tesla V100 32GB")
#   TARGET_VRAM_GB         - VRAM int (ex: 32)
#   ACCEPTED_GPU_REGEXES   - array bash cu regex-uri permise pentru nvidia-smi
#   PROXY_NOTE             - string non-gol => primul element e target real,
#                            restul sunt surogati. Gol => doar GPU exact.
# =============================================================================

set -euo pipefail

# Sourcing gpu_mapping.sh ca sa avem canonical_gpu_slug + SURROGATE_FOR
# (calea relativa la directorul acestui fisier, nu la CWD)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gpu_mapping.sh
source "${_LIB_DIR}/gpu_mapping.sh"

# Colorat doar daca avem terminal
if [[ -t 1 ]]; then
    C_R=$'\e[0;31m'; C_G=$'\e[0;32m'; C_Y=$'\e[1;33m'
    C_B=$'\e[0;34m'; C_C=$'\e[0;36m'; C_M=$'\e[0;35m'
    C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
    C_R=""; C_G=""; C_Y=""; C_B=""; C_C=""; C_M=""; C_BOLD=""; C_RESET=""
fi

log()      { echo "${C_C}[$(date +%H:%M:%S)]${C_RESET} $*"; }
log_info() { echo "${C_B}[INFO]${C_RESET} $*"; }
log_ok()   { echo "${C_G}[OK]${C_RESET} $*"; }
log_warn() { echo "${C_Y}[WARN]${C_RESET} $*"; }
log_err()  { echo "${C_R}[ERR]${C_RESET} $*" >&2; }
hr()       { echo "${C_C}=====================================================${C_RESET}"; }

# =============================================================================
# Variabile globale derivate (populate la rulare)
# =============================================================================
GPU_SLUG=""           # dirname final = canonical_gpu_slug(DETECTED_GPU, vram)
RESULTS_DIR=""        # results/<GPU_SLUG>/
DETECTED_GPU=""       # ce a returnat nvidia-smi --query-gpu=name
PROXY_MODE="false"    # "true" daca rulam pe surogat (DETECTED != target)
PROXY_FOR=""          # GPU_KEY-ul vizat (dpv business), daca proxy_mode
RUN_LOG=""            # path catre _run-log.txt
NVSMI_PID=""          # PID pentru nvidia-smi background process
RUN_TIMESTAMP=""      # ISO 8601, used pentru commit message

# =============================================================================
# phase_0_system_info
# =============================================================================
phase_0_system_info() {
    hr
    log_info "Phase 0: Colectare info sistem"
    hr

    RUN_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Detecteaza GPU + VRAM
    DETECTED_GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs || echo "unknown")
    local detected_vram_mb
    detected_vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs || echo 0)
    local detected_vram_gb=$(( (detected_vram_mb + 512) / 1024 ))   # round to nearest GB

    # Slug-ul = canonical pentru GPU-ul REAL detectat (consistent cu naming-ul
    # vechi pentru cele 5 target-uri, slug nou pentru fiecare surogat).
    # Astfel results/<slug>/ reflecta exact pe ce hardware s-a rulat.
    # Maparea "acest slug = surogat pentru ce target" e in summary.json[target_gpu]
    # si in gpu_mapping.sh::SURROGATE_FOR (fallback static).
    GPU_SLUG=$(canonical_gpu_slug "$DETECTED_GPU" "$detected_vram_gb")

    RESULTS_DIR="results/$GPU_SLUG"
    mkdir -p "$RESULTS_DIR"
    RUN_LOG="$RESULTS_DIR/_run-log.txt"

    log "Target GPU:    $TARGET_GPU (key: $GPU_KEY)"
    log "GPU detectat:  ${C_BOLD}$DETECTED_GPU${C_RESET} (~${detected_vram_gb} GB)"
    log "VRAM target:   ${TARGET_VRAM_GB} GB"
    log "Results dir:   ${C_BOLD}$RESULTS_DIR${C_RESET}"
    if [[ "$GPU_SLUG" != "$GPU_KEY" ]]; then
        log_warn "Surogat detectat. Director numit dupa GPU-ul real ($GPU_SLUG); summary.json contine target_gpu=$TARGET_GPU pentru a-l grupa cu target-ul."
    fi

    local sys_txt="$RESULTS_DIR/_system-info.txt"
    {
        echo "=== System info collected at $RUN_TIMESTAMP ==="
        echo
        echo "--- Target ---"
        echo "TARGET_GPU=$TARGET_GPU"
        echo "TARGET_VRAM_GB=$TARGET_VRAM_GB"
        echo "GPU_KEY=$GPU_KEY"
        echo
        echo "--- Detected ---"
        echo "DETECTED_GPU=$DETECTED_GPU"
        echo "GPU_SLUG (results dirname, dupa GPU REAL)=$GPU_SLUG"
        echo "PROXY_MODE=$([[ "$GPU_SLUG" != "$GPU_KEY" ]] && echo true || echo false)"
        echo
        echo "--- nvidia-smi ---"
        nvidia-smi 2>&1 || echo "nvidia-smi NOT AVAILABLE"
        echo
        echo "--- nvidia-smi --query-gpu (CSV) ---"
        nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version,compute_cap,pcie.link.gen.current,pcie.link.width.current --format=csv 2>&1 || true
        echo
        echo "--- lscpu ---"
        lscpu 2>&1 || true
        echo
        echo "--- free -h ---"
        free -h 2>&1 || true
        echo
        echo "--- df -h / ---"
        df -h / 2>&1 || true
        echo
        echo "--- lsb_release / uname ---"
        lsb_release -a 2>/dev/null || cat /etc/os-release 2>/dev/null || true
        echo "uname -a: $(uname -a)"
    } > "$sys_txt"

    # Versiune compacta in JSON
    local gpu_total_mb driver compute_cap cpu_model cpu_cores ram_gb proxy_flag
    gpu_total_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | xargs || echo 0)
    driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1 | xargs || echo "unknown")
    compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits | head -1 | xargs || echo "unknown")
    cpu_model=$(lscpu | grep -m1 "Model name" | sed 's/Model name: *//' | xargs || echo "unknown")
    cpu_cores=$(nproc 2>/dev/null || echo 0)
    ram_gb=$(free -g | awk '/^Mem:/{print $2}' 2>/dev/null || echo 0)
    proxy_flag=$([[ "$GPU_SLUG" != "$GPU_KEY" ]] && echo true || echo false)

    cat > "$RESULTS_DIR/_system-info.json" <<EOF
{
  "collected_at": "$RUN_TIMESTAMP",
  "target_gpu": "$TARGET_GPU",
  "target_vram_gb": $TARGET_VRAM_GB,
  "gpu_key": "$GPU_KEY",
  "detected_gpu": "$DETECTED_GPU",
  "gpu_slug": "$GPU_SLUG",
  "proxy_mode": $proxy_flag,
  "gpu_total_mb": $gpu_total_mb,
  "driver_version": "$driver",
  "compute_capability": "$compute_cap",
  "cpu_model": "$cpu_model",
  "cpu_cores": $cpu_cores,
  "ram_gb": $ram_gb
}
EOF
    log_ok "System info salvat in $RESULTS_DIR/_system-info.{json,txt}"
}

# =============================================================================
# phase_0b_verify_gpu - verifica match cu ACCEPTED_GPU_REGEXES
# =============================================================================
phase_0b_verify_gpu() {
    hr
    log_info "Phase 0b: Verificare GPU"
    hr

    log "GPU detectat: ${C_BOLD}$DETECTED_GPU${C_RESET}"

    if [[ -z "$DETECTED_GPU" || "$DETECTED_GPU" == "unknown" ]]; then
        log_err "Nu pot detecta GPU. Verifica nvidia-smi."
        exit 1
    fi

    local matched=""
    local match_idx=-1
    local i=0
    for regex in "${ACCEPTED_GPU_REGEXES[@]}"; do
        if [[ "$DETECTED_GPU" =~ $regex ]]; then
            matched="$regex"
            match_idx=$i
            break
        fi
        i=$((i + 1))
    done

    if [[ -z "$matched" ]]; then
        log_err "GPU '$DETECTED_GPU' NU e in lista permisa pentru acest script."
        log_err "Acceptate: ${ACCEPTED_GPU_REGEXES[*]}"
        log_err "Foloseste run.sh care selecteaza scriptul corect automat."
        exit 1
    fi

    if [[ $match_idx -eq 0 || -z "$PROXY_NOTE" ]]; then
        PROXY_MODE="false"
        PROXY_FOR=""
        log_ok "GPU TARGET match (regex '$matched')"
    else
        PROXY_MODE="true"
        PROXY_FOR="$TARGET_GPU"
        log_warn "GPU SUROGAT detectat - rulez ca proxy pentru ${C_BOLD}$TARGET_GPU${C_RESET}"
        log_warn "Nota: $PROXY_NOTE"
    fi
}

# =============================================================================
# phase_1_install_ollama - instaleaza Ollama daca lipseste, configureaza service
# =============================================================================
phase_1_install_ollama() {
    hr
    log_info "Phase 1: Setup Ollama"
    hr

    if command -v ollama >/dev/null 2>&1; then
        log_ok "Ollama deja instalat: $(ollama --version 2>&1 | head -1)"
    else
        log "Instalare Ollama via curl ollama.com/install.sh ..."
        curl -fsSL https://ollama.com/install.sh | sh
        log_ok "Ollama instalat: $(ollama --version 2>&1 | head -1)"
    fi

    # Configureaza env vars pentru optimizari + cold runs
    # OLLAMA_KEEP_ALIVE=0 = unload model imediat dupa request -> garanteaza cold run
    # OLLAMA_FLASH_ATTENTION=1 + KV_CACHE_TYPE=q8_0 = mai mult headroom VRAM
    # PASCAL nu suporta FA2 eficient -> dezactivam pentru P5000/P40/1080Ti
    local enable_fa=1
    local kv_cache="q8_0"
    if [[ "$DETECTED_GPU" =~ (P5000|P40|1080|P100) ]]; then
        log_warn "GPU Pascal detectat -> dezactivez FlashAttention si KV cache q8_0"
        enable_fa=0
        kv_cache="f16"
    fi

    log "Configurez systemd override pentru Ollama..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d 2>/dev/null || \
        mkdir -p /etc/systemd/system/ollama.service.d
    {
        cat <<EOF
[Service]
Environment="OLLAMA_KEEP_ALIVE=0"
Environment="OLLAMA_FLASH_ATTENTION=$enable_fa"
Environment="OLLAMA_KV_CACHE_TYPE=$kv_cache"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
EOF
    } | (sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null 2>&1 || \
         tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null)

    log "Restart Ollama service..."
    sudo systemctl daemon-reload 2>/dev/null || systemctl daemon-reload || true
    sudo systemctl restart ollama 2>/dev/null || systemctl restart ollama || \
        log_warn "Nu pot restart-a via systemctl, probabil rulez fara systemd"

    # Daca nu ruleaza ca service, porneste manual in background
    if ! curl -sf "$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
        log_warn "Ollama service nu raspunde, pornesc manual in background..."
        nohup ollama serve > /tmp/ollama-serve.log 2>&1 &
        sleep 3
    fi

    # Wait for Ollama API ready
    log "Astept ca Ollama API sa fie ready..."
    local tries=0
    while ! curl -sf "$OLLAMA_HOST/api/version" >/dev/null 2>&1; do
        sleep 1
        tries=$((tries + 1))
        if (( tries > 30 )); then
            log_err "Ollama nu raspunde dupa 30s"
            exit 1
        fi
    done
    log_ok "Ollama ready: $(curl -s $OLLAMA_HOST/api/version | head -c 200)"
}

# =============================================================================
# phase_2_select_models - filtreaza modelele care incap in VRAM
# =============================================================================
SELECTED_MODELS=()
phase_2_select_models() {
    hr
    log_info "Phase 2: Selectare modele care incap in ${TARGET_VRAM_GB}GB VRAM"
    hr

    SELECTED_MODELS=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        SELECTED_MODELS+=("$line")
    done < <(select_models_for_vram "$TARGET_VRAM_GB")

    log "Modele care vor fi rulate (${#SELECTED_MODELS[@]}):"
    local m
    for m in "${SELECTED_MODELS[@]}"; do
        local mf="${m%%|*}"
        local rest="${m#*|}"
        local cn="${rest%%|*}"
        local rest2="${rest#*|}"
        local base="${rest2%%|*}"
        local vram="${rest2##*|}"
        log "  - $cn  (base: $base, ~${vram}GB)"
    done

    if (( ${#SELECTED_MODELS[@]} == 0 )); then
        log_err "Nu exista modele care sa incapa in ${TARGET_VRAM_GB}GB. Abandon."
        exit 1
    fi
}

# =============================================================================
# phase_3_pull_and_create - pull base + create custom cu Modelfile
# =============================================================================
phase_3_pull_and_create() {
    hr
    log_info "Phase 3: Pull baza + create custom modele"
    hr

    local m
    for m in "${SELECTED_MODELS[@]}"; do
        local mf="${m%%|*}"
        local rest="${m#*|}"
        local cn="${rest%%|*}"
        local rest2="${rest#*|}"
        local base="${rest2%%|*}"

        log "Pull: ${C_BOLD}$base${C_RESET}"
        if timeout "$TIMEOUT_PULL_SEC" ollama pull "$base"; then
            log_ok "Pull OK: $base"
        else
            log_err "Pull FAILED: $base (timeout $TIMEOUT_PULL_SEC sec)"
            continue
        fi

        log "Create custom: $cn (din _common/modelfiles/$mf)"
        if ollama create "$cn" -f "_common/modelfiles/$mf"; then
            log_ok "Create OK: $cn"
        else
            log_err "Create FAILED: $cn"
        fi
    done

    log "Modele instalate:"
    ollama list || true
}

# =============================================================================
# Helpers pentru benchmark
# =============================================================================

# Lanseaza nvidia-smi polling in background, output CSV
# IMPORTANT: capturam PID-ul direct al lui nvidia-smi (nu al grupului bash)
# ca sa-l putem omori corect cu kill. Header-ul e scris separat inainte.
start_nvsmi_polling() {
    local out_csv="$1"
    echo "timestamp,gpu_util_pct,mem_used_mb,mem_total_mb,temp_c,power_w" > "$out_csv"
    nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
               --format=csv,noheader,nounits \
               -lms $((NVSMI_POLL_INTERVAL * 1000)) 2>/dev/null >> "$out_csv" &
    NVSMI_PID=$!
    sleep 0.5
}

stop_nvsmi_polling() {
    if [[ -n "$NVSMI_PID" ]]; then
        kill "$NVSMI_PID" 2>/dev/null || true
        wait "$NVSMI_PID" 2>/dev/null || true
        NVSMI_PID=""
    fi
    # Defensive: omoara orice nvidia-smi orfan ramas (in caz ca PID tracking a esuat)
    pkill -f "nvidia-smi.*query-gpu" 2>/dev/null || true
}

# Calculeaza statistici peste CSV nvidia-smi (vram peak, util avg, temp max, power avg)
# Output: 4 numere separate cu spatii: vram_peak_mb gpu_util_avg gpu_temp_max power_avg
analyze_nvsmi_csv() {
    local csv="$1"
    awk -F',' 'NR>1 {
        gsub(/^[ \t]+|[ \t]+$/, "", $2)
        gsub(/^[ \t]+|[ \t]+$/, "", $3)
        gsub(/^[ \t]+|[ \t]+$/, "", $5)
        gsub(/^[ \t]+|[ \t]+$/, "", $6)
        if ($3+0 > vram_peak) vram_peak = $3+0
        util_sum += $2+0; util_n++
        if ($5+0 > temp_max) temp_max = $5+0
        power_sum += $6+0; power_n++
        if ($6+0 > power_peak) power_peak = $6+0
    } END {
        if (util_n == 0) { print "0 0 0 0 0"; exit }
        printf "%d %.1f %d %.1f %.1f\n", vram_peak, util_sum/util_n, temp_max, power_sum/power_n, power_peak
    }' "$csv"
}

# Verifica daca un string e JSON valid
is_valid_json() {
    local s="$1"
    # Accept fie JSON pur, fie cu code fences markdown
    local cleaned
    cleaned=$(echo "$s" | sed -E 's/^```json[[:space:]]*//; s/^```[[:space:]]*//; s/[[:space:]]*```[[:space:]]*$//')
    echo "$cleaned" | python3 -c "import sys, json; json.loads(sys.stdin.read())" 2>/dev/null
}

# =============================================================================
# phase_4_run_benchmarks - bucla principala
# =============================================================================
phase_4_run_benchmarks() {
    hr
    log_info "Phase 4: Benchmark cold per model"
    hr

    local prompt_file="prompt_test.txt"
    if [[ ! -f "$prompt_file" ]]; then
        log_err "Lipseste $prompt_file in directorul curent"
        exit 1
    fi
    local prompt_chars
    prompt_chars=$(wc -c < "$prompt_file")
    log "Prompt: $prompt_file ($prompt_chars caractere, ~$((prompt_chars / 4)) tokens)"

    local m
    for m in "${SELECTED_MODELS[@]}"; do
        local mf="${m%%|*}"
        local rest="${m#*|}"
        local cn="${rest%%|*}"
        local rest2="${rest#*|}"
        local base="${rest2%%|*}"
        local min_vram="${rest2##*|}"

        hr
        log_info "Benchmark COLD: ${C_BOLD}$cn${C_RESET} (base: $base, ~${min_vram}GB)"
        hr

        local response_file="$RESULTS_DIR/${cn}-response.txt"
        local metrics_file="$RESULTS_DIR/${cn}-metrics.json"
        local nvsmi_file="$RESULTS_DIR/${cn}-nvsmi.csv"

        # Skip daca avem deja metrics OK pentru acest model (idempotent re-run)
        if [[ -f "$metrics_file" ]] && \
           python3 -c "import json,sys; sys.exit(0 if json.load(open('$metrics_file')).get('status')=='OK' else 1)" 2>/dev/null; then
            log_ok "Skip $cn - metrics OK exista deja (re-run idempotent)"
            continue
        fi

        # Force unload modele anterioare ca sa fie cold
        log "Force unload modele in VRAM (keep_alive=0)..."
        ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}' | while read -r loaded; do
            [[ -n "$loaded" ]] && ollama stop "$loaded" 2>/dev/null || true
        done
        sleep 2

        # Build payload JSON cu prompt-ul
        local payload
        payload=$(python3 -c "
import json, sys
with open('$prompt_file') as f:
    prompt = f.read()
print(json.dumps({
    'model': '$cn',
    'prompt': prompt,
    'stream': False,
    'options': {
        'temperature': $SAMPLING_TEMPERATURE,
        'seed': $SAMPLING_SEED,
        'num_ctx': $NUM_CTX
    }
}))")

        # Pornim nvidia-smi polling
        start_nvsmi_polling "$nvsmi_file"

        local start_ts end_ts wall_time status="OK" failure_reason="null"
        start_ts=$(date +%s.%N)

        local response_json
        if response_json=$(echo "$payload" | timeout "$TIMEOUT_PER_MODEL_SEC" \
                            curl -sf -X POST "$OLLAMA_HOST/api/generate" \
                                 -H "Content-Type: application/json" \
                                 -d @- 2>&1); then
            end_ts=$(date +%s.%N)
            wall_time=$(echo "$end_ts - $start_ts" | bc -l)
            log_ok "Request OK in $(printf '%.1f' "$wall_time")s"
        else
            local exit_code=$?
            end_ts=$(date +%s.%N)
            wall_time=$(echo "$end_ts - $start_ts" | bc -l)
            stop_nvsmi_polling
            if [[ $exit_code -eq 124 ]]; then
                status="TIMEOUT"
                failure_reason="\"Timeout dupa ${TIMEOUT_PER_MODEL_SEC}s\""
            else
                status="FAILED"
                # Detect OOM in error message
                if [[ "$response_json" =~ (out of memory|OOM|cudaMalloc|insufficient) ]]; then
                    status="OOM"
                fi
                local clean_err
                clean_err=$(echo "$response_json" | tr '\n' ' ' | head -c 500 | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")
                failure_reason="$clean_err"
            fi
            log_err "Request $status in $(printf '%.1f' "$wall_time")s"
            # Salveaza metrici partial si treci la urmatorul
            write_failed_metrics "$metrics_file" "$cn" "$base" "$min_vram" "$status" "$failure_reason" "$wall_time" "$nvsmi_file"
            continue
        fi

        stop_nvsmi_polling

        # Parse response JSON pentru a extrage metrici Ollama
        echo "$response_json" > "$RESULTS_DIR/${cn}-raw-api-response.json"
        # Salveaza raspunsul brut LLM
        echo "$response_json" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
sys.stdout.write(data.get('response', ''))
" > "$response_file"

        local resp_chars resp_is_json
        resp_chars=$(wc -c < "$response_file")
        if is_valid_json "$(cat "$response_file")"; then
            resp_is_json="true"
            log_ok "Response e JSON valid ($resp_chars chars)"
        else
            resp_is_json="false"
            log_warn "Response NU e JSON valid ($resp_chars chars)"
        fi

        # Calculeaza statistici nvidia-smi
        local nvsmi_stats vram_peak gpu_util_avg gpu_temp_max power_avg power_peak
        nvsmi_stats=$(analyze_nvsmi_csv "$nvsmi_file")
        read -r vram_peak gpu_util_avg gpu_temp_max power_avg power_peak <<< "$nvsmi_stats"

        local raw_api_file="$RESULTS_DIR/${cn}-raw-api-response.json"
        write_ok_metrics "$metrics_file" "$cn" "$base" "$min_vram" \
                         "$wall_time" "$raw_api_file" "$resp_chars" "$resp_is_json" \
                         "$vram_peak" "$gpu_util_avg" "$gpu_temp_max" "$power_avg" "$power_peak"

        log_ok "Metrici salvati in $metrics_file"
    done
}

# =============================================================================
# write_ok_metrics - salveaza metrici pentru un run reusit
# =============================================================================
write_ok_metrics() {
    local metrics_file="$1" cn="$2" base="$3" min_vram="$4" wall_time="$5"
    local raw_api_file="$6" resp_chars="$7" resp_is_json="$8"
    local vram_peak="$9" gpu_util_avg="${10}" gpu_temp_max="${11}"
    local power_avg="${12}" power_peak="${13}"

    local purchase_price vast_hourly cost_per_analysis breakeven analyses_per_day
    purchase_price=$(get_price "$GPU_KEY" "purchase")
    vast_hourly=$(get_price "$GPU_KEY" "vast_hourly")
    cost_per_analysis=$(echo "scale=8; ($wall_time / 3600) * $vast_hourly" | bc -l)
    if (( $(echo "$cost_per_analysis > 0" | bc -l) )); then
        breakeven=$(echo "scale=0; $purchase_price / $cost_per_analysis" | bc -l)
    else
        breakeven=0
    fi
    analyses_per_day=$(echo "scale=0; 86400 / $wall_time" | bc -l)

    # Extract Ollama metrics din raw_api_file (citit din fisier - stdin e deja consumat de heredoc)
    python3 - "$metrics_file" "$cn" "$base" "$min_vram" "$wall_time" "$resp_chars" "$resp_is_json" \
              "$vram_peak" "$gpu_util_avg" "$gpu_temp_max" "$power_avg" "$power_peak" \
              "$purchase_price" "$vast_hourly" "$cost_per_analysis" "$breakeven" "$analyses_per_day" \
              "$GPU_KEY" "$TARGET_GPU" "$DETECTED_GPU" "$PROXY_MODE" "$PROXY_FOR" "$RUN_TIMESTAMP" \
              "$raw_api_file" <<EOF
import json, sys
metrics_file = sys.argv[1]
cn = sys.argv[2]; base = sys.argv[3]; min_vram = int(sys.argv[4])
wall_time = float(sys.argv[5]); resp_chars = int(sys.argv[6])
resp_is_json = sys.argv[7] == "true"
vram_peak = int(float(sys.argv[8])); gpu_util_avg = float(sys.argv[9])
gpu_temp_max = int(float(sys.argv[10])); power_avg = float(sys.argv[11])
power_peak = float(sys.argv[12])
purchase_price = float(sys.argv[13]); vast_hourly = float(sys.argv[14])
cost_per_analysis = float(sys.argv[15]); breakeven = int(float(sys.argv[16]))
analyses_per_day = int(float(sys.argv[17]))
gpu_key = sys.argv[18]; target_gpu = sys.argv[19]; detected_gpu = sys.argv[20]
proxy_mode = sys.argv[21] == "true"; proxy_for = sys.argv[22]
run_ts = sys.argv[23]
raw_api_file = sys.argv[24]

with open(raw_api_file) as f:
    data = json.load(f)

prompt_eval_count = data.get("prompt_eval_count", 0)
prompt_eval_duration_ns = data.get("prompt_eval_duration", 0)
eval_count = data.get("eval_count", 0)
eval_duration_ns = data.get("eval_duration", 0)
load_duration_ns = data.get("load_duration", 0)
total_duration_ns = data.get("total_duration", 0)

prompt_eval_rate = (prompt_eval_count / (prompt_eval_duration_ns / 1e9)) if prompt_eval_duration_ns > 0 else 0
eval_rate = (eval_count / (eval_duration_ns / 1e9)) if eval_duration_ns > 0 else 0

out = {
    "model": cn,
    "model_base": base,
    "model_min_vram_gb": min_vram,
    "status": "OK",
    "failure_reason": None,
    "run_type": "cold",
    "timestamp_utc": run_ts,
    "gpu_key": gpu_key,
    "target_gpu": target_gpu,
    "detected_gpu": detected_gpu,
    "proxy_mode": proxy_mode,
    "proxy_for": proxy_for if proxy_mode else None,
    "wall_time_sec": round(wall_time, 3),
    "load_duration_sec": round(load_duration_ns / 1e9, 3),
    "total_duration_sec": round(total_duration_ns / 1e9, 3),
    "prompt_eval_count": prompt_eval_count,
    "prompt_eval_duration_sec": round(prompt_eval_duration_ns / 1e9, 3),
    "prompt_eval_rate_tok_per_sec": round(prompt_eval_rate, 2),
    "eval_count": eval_count,
    "eval_duration_sec": round(eval_duration_ns / 1e9, 3),
    "eval_rate_tok_per_sec": round(eval_rate, 2),
    "vram_peak_mb": vram_peak,
    "gpu_util_avg_pct": gpu_util_avg,
    "gpu_temp_max_c": gpu_temp_max,
    "power_avg_w": round(power_avg, 1),
    "power_peak_w": round(power_peak, 1),
    "response_chars": resp_chars,
    "response_is_valid_json": resp_is_json,
    "purchase_price_usd": purchase_price,
    "vast_price_per_hour_usd": vast_hourly,
    "cost_per_analysis_usd": round(cost_per_analysis, 6),
    "breakeven_analyses_vs_vast": breakeven,
    "analyses_per_day_at_24_7": analyses_per_day,
}
with open(metrics_file, "w") as f:
    json.dump(out, f, indent=2)
EOF
}

# =============================================================================
# write_failed_metrics - salveaza metrici pentru un run esuat
# =============================================================================
write_failed_metrics() {
    local metrics_file="$1" cn="$2" base="$3" min_vram="$4"
    local status="$5" failure_reason="$6" wall_time="$7" nvsmi_file="$8"

    local nvsmi_stats vram_peak gpu_util_avg gpu_temp_max power_avg power_peak
    if [[ -f "$nvsmi_file" ]]; then
        nvsmi_stats=$(analyze_nvsmi_csv "$nvsmi_file")
        read -r vram_peak gpu_util_avg gpu_temp_max power_avg power_peak <<< "$nvsmi_stats"
    else
        vram_peak=0; gpu_util_avg=0; gpu_temp_max=0; power_avg=0; power_peak=0
    fi

    local purchase_price vast_hourly
    purchase_price=$(get_price "$GPU_KEY" "purchase")
    vast_hourly=$(get_price "$GPU_KEY" "vast_hourly")

    cat > "$metrics_file" <<EOF
{
  "model": "$cn",
  "model_base": "$base",
  "model_min_vram_gb": $min_vram,
  "status": "$status",
  "failure_reason": $failure_reason,
  "run_type": "cold",
  "timestamp_utc": "$RUN_TIMESTAMP",
  "gpu_key": "$GPU_KEY",
  "target_gpu": "$TARGET_GPU",
  "detected_gpu": "$DETECTED_GPU",
  "proxy_mode": $PROXY_MODE,
  "proxy_for": $([ "$PROXY_MODE" = "true" ] && echo "\"$PROXY_FOR\"" || echo "null"),
  "wall_time_sec": $(printf '%.3f' "$wall_time"),
  "vram_peak_mb": $vram_peak,
  "gpu_util_avg_pct": $gpu_util_avg,
  "gpu_temp_max_c": $gpu_temp_max,
  "power_avg_w": $power_avg,
  "power_peak_w": $power_peak,
  "purchase_price_usd": $purchase_price,
  "vast_price_per_hour_usd": $vast_hourly
}
EOF
}

# =============================================================================
# phase_5_generate_report - agregare metrici per GPU
# =============================================================================
phase_5_generate_report() {
    hr
    log_info "Phase 5: Generare summary per GPU"
    hr

    local summary_json="$RESULTS_DIR/summary.json"
    local summary_md="$RESULTS_DIR/summary.md"

    python3 - "$RESULTS_DIR" "$GPU_KEY" "$TARGET_GPU" "$DETECTED_GPU" "$PROXY_MODE" "$PROXY_FOR" \
              "$TARGET_VRAM_GB" "$RUN_TIMESTAMP" \
              "$(get_price "$GPU_KEY" "purchase")" \
              "$(get_price "$GPU_KEY" "vast_hourly")" \
              "$(get_price "$GPU_KEY" "source")" <<'PYEOF'
import json, sys, os, glob

results_dir = sys.argv[1]
gpu_key = sys.argv[2]; target_gpu = sys.argv[3]; detected_gpu = sys.argv[4]
proxy_mode = sys.argv[5] == "true"; proxy_for = sys.argv[6]
target_vram_gb = int(sys.argv[7]); run_ts = sys.argv[8]
purchase_price = float(sys.argv[9]); vast_hourly = float(sys.argv[10])
purchase_source = sys.argv[11]

models = []
for f in sorted(glob.glob(f"{results_dir}/*-metrics.json")):
    if f.endswith("summary.json"):
        continue
    with open(f) as fp:
        models.append(json.load(fp))

ok_models = [m for m in models if m.get("status") == "OK"]
fail_models = [m for m in models if m.get("status") != "OK"]

summary = {
    "gpu_key": gpu_key,
    "target_gpu": target_gpu,
    "detected_gpu": detected_gpu,
    "proxy_mode": proxy_mode,
    "proxy_for": proxy_for if proxy_mode else None,
    "target_vram_gb": target_vram_gb,
    "purchase_price_usd": purchase_price,
    "purchase_source": purchase_source,
    "vast_price_per_hour_usd": vast_hourly,
    "benchmark_timestamp_utc": run_ts,
    "models_tested": len(models),
    "models_ok": len(ok_models),
    "models_failed": len(fail_models),
    "models": models,
}

summary_json = f"{results_dir}/summary.json"
with open(summary_json, "w") as fp:
    json.dump(summary, fp, indent=2)
print(f"[OK] Summary JSON: {summary_json}")

# Markdown summary
lines = []
lines.append(f"# Benchmark summary: target = {target_gpu}")
lines.append("")
lines.append(f"## ⚠ EXECUTAT PE: `{detected_gpu}`")
lines.append("")
if proxy_mode:
    lines.append(f"- **Proxy mode:** DA")
    lines.append(f"- **Target real (cumparat):** `{proxy_for}`")
    lines.append(f"- **Surogat folosit:** `{detected_gpu}`")
    if detected_gpu != proxy_for:
        lines.append(f"- ⚠ **Atentie:** rezultatele reflecta perfomanta lui `{detected_gpu}`, NU a target-ului. Verifica daca surogatul e lower-bound real (mai slab pe compute SI bandwidth) sau optimist (mai puternic) inainte de a folosi cifrele pentru decizia de cumparare.")
else:
    lines.append(f"- **Proxy mode:** NU - rulat pe target real")
lines.append(f"- **VRAM target:** {target_vram_gb} GB")
lines.append(f"- **Pret cumparare:** ${purchase_price:.0f} ({purchase_source})")
lines.append(f"- **Vast.ai $/hr:** ${vast_hourly:.3f}")
lines.append(f"- **Timestamp:** {run_ts}")
lines.append(f"- **Modele rulate:** {len(models)} (OK: {len(ok_models)}, FAILED: {len(fail_models)})")
lines.append("")
lines.append("## Per-model metrics")
lines.append("")
lines.append("| Model | Status | Wall (s) | Prompt eval (tok/s) | Output eval (tok/s) | Output tokens | VRAM peak (MB) | Cost/analiza ($) | Valid JSON |")
lines.append("|---|---|---:|---:|---:|---:|---:|---:|:---:|")

for m in models:
    status = m.get("status", "?")
    wall = m.get("wall_time_sec", 0)
    pe_rate = m.get("prompt_eval_rate_tok_per_sec", 0)
    ev_rate = m.get("eval_rate_tok_per_sec", 0)
    ev_count = m.get("eval_count", 0)
    vram_peak = m.get("vram_peak_mb", 0)
    cost = m.get("cost_per_analysis_usd", 0)
    is_json = "YES" if m.get("response_is_valid_json") else "NO" if m.get("response_is_valid_json") is False else "-"
    lines.append(f"| `{m.get('model', '?')}` | {status} | {wall:.1f} | {pe_rate:.1f} | {ev_rate:.1f} | {ev_count} | {vram_peak} | {cost:.6f} | {is_json} |")

if fail_models:
    lines.append("")
    lines.append("## Failures")
    lines.append("")
    for m in fail_models:
        lines.append(f"- **{m.get('model')}** ({m.get('status')}): `{m.get('failure_reason', '-')}`")

summary_md = f"{results_dir}/summary.md"
with open(summary_md, "w") as fp:
    fp.write("\n".join(lines) + "\n")
print(f"[OK] Summary MD: {summary_md}")

# Print pe ecran
print()
print("=" * 60)
print(f" SUMMARY {target_gpu}")
print("=" * 60)
for m in models:
    print(f"  {m.get('model'):20s}  {m.get('status', '?'):8s}  wall={m.get('wall_time_sec', 0):6.1f}s  cost=${m.get('cost_per_analysis_usd', 0):.6f}")
PYEOF

    log_ok "Summary salvat in $summary_json + .md"
}

# =============================================================================
# git_push_results - commit & push results/<slug>/ in repo (auto)
# =============================================================================
phase_6_git_push_results() {
    hr
    log_info "Phase 6: Git push rezultate"
    hr

    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_warn "Variabila GITHUB_TOKEN nu e setata."
        log_warn "Pentru auto-push pe instantele viitoare:"
        log_warn "  1. Genereaza fine-grained PAT: https://github.com/settings/personal-access-tokens"
        log_warn "  2. In Vast.ai: Account -> Templates -> adauga env GITHUB_TOKEN=<pat>"
        log_warn ""
        log_warn "Fallback manual - tarball local:"
        local tarball="${GPU_KEY}-RESULTS-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar czf "$tarball" "$RESULTS_DIR"
        log_warn "  Creat: $tarball"
        log_warn "  Descarca cu (din statia ta locala):"
        local ssh_host="${SSH_HOST:-<HOST>}"
        local ssh_port="${SSH_PORT:-<PORT>}"
        local pwd_dir
        pwd_dir=$(pwd)
        log_warn "    scp -P $ssh_port root@$ssh_host:$pwd_dir/$tarball ./"
        return 0
    fi

    # Detecteaza repo URL si extrage owner/repo
    local remote_url owner_repo
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        log_err "Nu sunt intr-un repo git (origin lipseste). Skip push."
        return 1
    fi
    # Suporta atat https://github.com/o/r.git cat si git@github.com:o/r.git
    owner_repo=$(echo "$remote_url" | sed -E 's|^https://[^/]+/||; s|^git@[^:]+:||; s|\.git$||')
    log "Remote: $owner_repo"

    # Configureaza autentificare HTTPS cu token
    git config user.email "vast-bench@noreply.local" 2>/dev/null || true
    git config user.name "Vast.ai $GPU_KEY" 2>/dev/null || true
    git remote set-url origin "https://oauth2:${GITHUB_TOKEN}@github.com/${owner_repo}.git"

    # Defensive: omoara orice nvidia-smi orfan inainte sa colectam fisierele
    pkill -f "nvidia-smi.*query-gpu" 2>/dev/null || true
    sleep 1

    # Add results
    cd "$(git rev-parse --show-toplevel)"
    git add "test-card/$RESULTS_DIR" 2>/dev/null || git add "$RESULTS_DIR" 2>/dev/null || true

    if git diff --cached --quiet; then
        log_warn "Nimic nou de comis. Skip push."
        return 0
    fi

    git commit -m "results: $GPU_KEY benchmark $(date -u +%Y%m%d-%H%M%S)" || {
        log_err "Commit failed"
        return 1
    }

    # Push cu retry. La fiecare iteratie:
    #   1. Stage orice modificare aparuta intre timp (nvidia-smi orfan, log size, etc.)
    #   2. Daca exista, amend la commit-ul existent
    #   3. pull --rebase + push
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    local i
    for ((i=1; i<=GIT_PUSH_MAX_RETRIES; i++)); do
        log "Push attempt $i/$GIT_PUSH_MAX_RETRIES (branch: $current_branch)..."

        # Inca o data: pkill in caz ca a aparut ceva nou
        pkill -f "nvidia-smi.*query-gpu" 2>/dev/null || true
        # Stage orice modificare ramasa in results/ si amend
        git add "test-card/$RESULTS_DIR" 2>/dev/null || git add "$RESULTS_DIR" 2>/dev/null || true
        if ! git diff --cached --quiet; then
            log "Modificari noi detectate, amend la commit..."
            git commit --amend --no-edit || true
        fi

        if git pull --rebase origin "$current_branch" && git push origin "$current_branch"; then
            log_ok "Push reusit! Rezultatele sunt in repo."
            log_ok "Local fa: ${C_BOLD}git pull${C_RESET}"
            log_ok "Apoi: ${C_BOLD}cd test-card/ && ./compare-results.sh${C_RESET}"
            return 0
        fi
        log_warn "Push attempt $i a esuat, retry in 5s..."
        sleep 5
    done

    log_err "Push esuat dupa $GIT_PUSH_MAX_RETRIES incercari."
    log_err "Fallback - rezolva manual:"
    git status
    return 1
}

# =============================================================================
# main_pipeline - orchestrator
# =============================================================================
main_pipeline() {
    # Tee output-urile in _run-log.txt (creat dupa phase_0)
    # IMPORTANT: phase_6 (git push) NU e in tee block-ul cu RUN_LOG, altfel ar
    # modifica _run-log.txt chiar in timp ce incearca push -> race condition cu
    # `git pull --rebase` care vede unstaged changes si refuza.
    phase_0_system_info
    {
        phase_0b_verify_gpu
        phase_1_install_ollama
        phase_2_select_models
        phase_3_pull_and_create
        phase_4_run_benchmarks
        phase_5_generate_report
        log "==> Pipeline phases 0-5 done. Predand catre phase 6 (git push) - logging muta in /tmp."
    } 2>&1 | tee -a "$RUN_LOG"

    # phase_6 logheaza separat in /tmp ca sa nu modifice _run-log.txt in timpul push-ului
    local push_log="/tmp/push-${GPU_SLUG}-$(date +%s).log"
    phase_6_git_push_results 2>&1 | tee "$push_log"
    log "Push log salvat la: $push_log"

    hr
    log_ok "BENCHMARK COMPLET pentru $TARGET_GPU"
    log "Reminder: opreste manual instanta Vast.ai din web UI (Destroy)."
    hr
}
