# Benchmark summary: target = RTX 5060 Ti 16GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 5060 Ti`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 16 GB
- **Pret cumparare:** $696 (eMAG nou (MSI Shadow 2X OC Plus))
- **Vast.ai $/hr:** $0.064
- **Timestamp:** 2026-04-22T04:24:07Z
- **Modele rulate:** 3 (OK: 2, FAILED: 1)

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
| `mss-14b-q4` | OK | 63488 | 55296 | 32768 | 477.9 | 683.7 | 8.5 | 3374 | 12766 | 0.008495 | YES |
| `mss-3b` | TIMEOUT | 429056 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 4768 | 0.000000 | - |
| `mss-7b` | OK | 257024 | 55296 | 32768 | 561.6 | 2278.4 | 40.9 | 21045 | 9526 | 0.009983 | YES |

## Failures

- **mss-3b** (TIMEOUT): `Timeout dupa 900s`
