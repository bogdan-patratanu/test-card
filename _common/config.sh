# =============================================================================
# config.sh - Tunables globale pentru toate scripturile de benchmark
# Sursa unica de adevar pentru constantele care nu depind de GPU specific.
# =============================================================================

# Cursul de schimb folosit pentru conversiile RON -> USD din raportul final
EXCHANGE_RATE_RON_USD=4.33

# Timeout per model (secunde). Daca un model nu termina in acest timp, scriptul
# il marcheaza FAILED si trece la urmatorul. 900s = 15 min (mai relaxat decat
# inainte pentru ca pe carduri lente cu ctx mare, modelele 32B pot dura mult).
TIMEOUT_PER_MODEL_SEC=900

# Timeout pentru pull (download model de pe Ollama hub). Modelele mari ~20GB.
TIMEOUT_PULL_SEC=1800

# Frecventa polling nvidia-smi (secunde intre samples)
NVSMI_POLL_INTERVAL=1

# Numarul de retry-uri pentru git push la conflict (improbabil, dar safety net)
GIT_PUSH_MAX_RETRIES=3

# Endpoint Ollama (default local)
OLLAMA_HOST="http://localhost:11434"

# =============================================================================
# CONFIGURARE CONTEXT (num_ctx) - ADAPTIV PER GPU+MODEL
# =============================================================================
# Inainte foloseam num_ctx fix = 32768. Problema: prompt-ul depasea acest ctx
# si Ollama trunchea SILENT instructiunile de la inceputul prompt-ului.
# Plus: nu e fair sa testezi un V100 32GB cu acelasi ctx ca un A2000 12GB.
#
# Acum strategia e:
#   1. Detecteaza VRAM total al GPU-ului
#   2. Pentru fiecare model: calculeaza max ctx care intra (formula KV cache)
#   3. Verifica: prompt_tokens <= max_ctx_predicted ? OK : SKIP
#   4. Ruleaza cu ctx = min(max_ctx_predicted, MAX_CTX_CAP, prompt * OVERSHOOT)
# =============================================================================

# Cap superior absolut. Nu trecem peste asta indiferent de cat VRAM e disponibil.
# 131072 = 128K tokens. Dincolo de asta scaling-ul e foarte slab oricum.
MAX_CTX_CAP=131072

# Safety margin VRAM (MB). Lasam liber peste model + KV cache. Notes:
# - model_size_mb din model_tiers.sh include DEJA activations + workspace
#   (calibrat din masuratori reale), deci safety_margin nu trebuie inflated.
# - 768 MB acopera fragmentare CUDA + alte procese minore + variabilitate driver.
# - Daca apar OOM-uri, mareste la 1024 sau 1536.
VRAM_SAFETY_MARGIN_MB=768

# Factor de overshoot peste prompt_tokens. ctx_target = needed * NUM/DEN.
# 3/2 = 1.5x = 50% headroom peste (prompt + response_buffer).
# Bash face doar int math, asa ca exprimam ratio.
CTX_OVERSHOOT_FACTOR_NUM=3
CTX_OVERSHOOT_FACTOR_DEN=2

# Tokens minimi alocati pentru raspuns peste prompt_tokens (buffer output).
# Schema JSON ceruta produce ~600-1500 tokens output in practica, asa ca 2048
# e suficient. Daca cresti, scazi sansa ca cardurile mici sa intre.
MIN_RESPONSE_TOKENS_BUFFER=2048

# =============================================================================
# OPTIMIZARI OLLAMA (gratuite ca beneficiu)
# =============================================================================

# Flash Attention 2 - reduce memory footprint pentru attention layers ~2x.
# Standard de productie acum, zero risc de calitate.
OLLAMA_FLASH_ATTENTION=1

# KV cache quantization - q8_0 reduce KV cache memory ~2x cu pierdere
# minora de calitate (sub 0.1% in benchmarks publici, neglijabil cu temperature=0).
# Optiuni: f16 (default, full quality), q8_0 (recomandat), q4_0 (agresiv).
OLLAMA_KV_CACHE_TYPE="q8_0"

# Force unload modele dupa fiecare request (pentru cold runs reproductibile)
OLLAMA_KEEP_ALIVE="0"

# =============================================================================
# Sampling determinist pentru a putea compara 1:1 intre GPU-uri
# =============================================================================
SAMPLING_TEMPERATURE=0
SAMPLING_SEED=42

# Versiunea minima Ollama (informativ, nu blocheaza)
# Flash Attention si KV quantization sunt suportate de la 0.4.0+
OLLAMA_MIN_VERSION="0.4.0"
