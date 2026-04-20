# =============================================================================
# config.sh - Tunables globale pentru toate scripturile de benchmark
# Sursa unica de adevar pentru constantele care nu depind de GPU specific.
# =============================================================================

# Cursul de schimb folosit pentru conversiile RON -> USD din raportul final
EXCHANGE_RATE_RON_USD=4.33

# Timeout per model (secunde). Daca un model nu termina in acest timp, scriptul
# il marcheaza FAILED si trece la urmatorul. 600s = 10 min.
TIMEOUT_PER_MODEL_SEC=600

# Timeout pentru pull (download model de pe Ollama hub). Modelele mari ~20GB.
TIMEOUT_PULL_SEC=1800

# Frecventa polling nvidia-smi (secunde intre samples)
NVSMI_POLL_INTERVAL=1

# Numarul de retry-uri pentru git push la conflict (improbabil, dar safety net)
GIT_PUSH_MAX_RETRIES=3

# Endpoint Ollama (default local)
OLLAMA_HOST="http://localhost:11434"

# Context window pentru toate modelele (acopera prompt ~26k + output ~5k)
NUM_CTX=32768

# Sampling determinist pentru a putea compara 1:1 intre GPU-uri
SAMPLING_TEMPERATURE=0
SAMPLING_SEED=42

# Versiunea minima Ollama (informativ, nu blocheaza)
OLLAMA_MIN_VERSION="0.5.0"
