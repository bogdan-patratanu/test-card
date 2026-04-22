# Benchmark summary: target = RTX 5060 Ti 16GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 5060 Ti`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 16 GB
- **Pret cumparare:** $696 (eMAG nou (MSI Shadow 2X OC Plus))
- **Vast.ai $/hr:** $0.064
- **Timestamp:** 2026-04-22T02:59:45Z
- **Modele rulate:** 3 (OK: 3, FAILED: 0)

## Configurare ctx (adaptiv per model)

ctx-ul a fost calculat pentru fiecare model in functie de:
- VRAM total al cardului efectiv detectat
- Marimea modelului in VRAM (din arhitectura)
- KV cache per token (din arhitectura, la quantization q8_0)
- Safety margin pentru activations + CUDA workspace

Modelele care nu ar fi avut ctx suficient pentru prompt-ul tau au fost EXCLUSE din start in phase_2 (NU apar in raport ca PROMPT_TOO_LARGE).

## Per-model metrics

| Model | Status | ctx max | ctx used | Prompt tok | Wall (s) | PromptEval tok/s | Eval tok/s | Output tok | VRAM peak MB | Cost/analiza $ | JSON |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| `mss-14b-q4` | OK | 63488 | 55296 | 32768 | 349.9 | 660.6 | 8.4 | 2238 | 12764 | 0.006221 | YES |
| `mss-3b` | OK | 429056 | 55296 | 32768 | 55.1 | 4762.2 | 82.8 | 493 | 4764 | 0.000980 | YES |
| `mss-7b` | OK | 257024 | 55296 | 32768 | 45.7 | 2274.7 | 39.9 | 488 | 9524 | 0.000813 | YES |
