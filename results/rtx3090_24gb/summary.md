# Benchmark summary: target = RTX 3090 24GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 3090`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 24 GB
- **Pret cumparare:** $760 (OLX Bucuresti (Zotac/Asus 24GB))
- **Vast.ai $/hr:** $0.160
- **Timestamp:** 2026-04-22T02:59:26Z
- **Modele rulate:** 9 (OK: 7, FAILED: 2)

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
| `mss-14b` | OK | 61440 | 55296 | 32768 | 134.1 | 1508.0 | 20.3 | 2146 | 21028 | 0.005961 | YES |
| `mss-14b-q4` | OK | 152576 | 55296 | 32768 | 89.6 | 1603.1 | 35.8 | 2251 | 14998 | 0.003982 | YES |
| `mss-32b-q3` | OK | 54272 | 54272 | 32768 | 111.5 | 707.6 | 7.8 | 475 | 21310 | 0.004955 | YES |
| `mss-32b-q4` | OK | 50176 | 50176 | 32768 | 369.2 | 485.1 | 1.7 | 489 | 21194 | 0.016410 | YES |
| `mss-3b` | OK | 731136 | 55296 | 32768 | 31.1 | 5945.2 | 138.1 | 493 | 4928 | 0.001381 | YES |
| `mss-7b` | OK | 559104 | 55296 | 32768 | 21.6 | 3300.3 | 64.6 | 488 | 9696 | 0.000960 | YES |
| `mss-qwq-32b` | TIMEOUT | 50176 | 50176 | 0 | 900.1 | 0.0 | 0.0 | 0 | 20160 | 0.000000 | - |
| `mss-r1-14b` | OK | 125952 | 55296 | 55296 | 290.1 | 1031.8 | 12.1 | 2785 | 18836 | 0.012894 | YES |
| `mss-r1-32b` | TIMEOUT | 50176 | 50176 | 0 | 900.0 | 0.0 | 0.0 | 0 | 19348 | 0.000000 | - |

## ⚠ Truncari detectate

Modele unde `prompt_eval_count >= ctx_used` (Ollama a trunchiat prompt-ul):
- **mss-r1-14b**: ctx_used=55296, prompt_real=55296

Cauza probabila: estimare initiala chars/3 a fost prea optimista (tokenizer-ul real produce mai multi tokens pe acest tip de continut). Solutie: creste safety in PROMPT_TOKENS_EST.

## Failures

- **mss-qwq-32b** (TIMEOUT): `Timeout dupa 900s`
- **mss-r1-32b** (TIMEOUT): `Timeout dupa 900s`
