# Benchmark summary: target = Tesla V100 32GB

## ⚠ EXECUTAT PE: `Tesla V100-SXM2-32GB`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 32 GB
- **Pret cumparare:** $860 (OLX Snagov (server card, necesita racire externa))
- **Vast.ai $/hr:** $0.210
- **Timestamp:** 2026-04-20T13:33:21Z
- **Modele rulate:** 6 (OK: 6, FAILED: 0)

## Configurare ctx (adaptiv per model)

ctx-ul a fost calculat pentru fiecare model in functie de:
- VRAM total al cardului efectiv detectat
- Marimea modelului in VRAM (din arhitectura)
- KV cache per token (din arhitectura, la quantization q8_0)
- Safety margin pentru activations + CUDA workspace

Daca `ctx_max_fits < prompt_tokens + buffer raspuns`, modelul e marcat **PROMPT_TOO_LARGE** (cardul nu poate procesa prompt-ul tau cu acest model).

## Per-model metrics

| Model | Status | ctx max | ctx used | Prompt tok | Wall (s) | PromptEval tok/s | Eval tok/s | Output tok | VRAM peak MB | Cost/analiza $ | JSON |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| `mss-14b` | OK | 148480 | 55296 | 32768 | 152.2 | 1026.0 | 26.7 | 2209 | 22633 | 0.008879 | YES |
| `mss-32b-q3` | OK | 119808 | 55296 | 32768 | 131.6 | 505.2 | 15.4 | 485 | 23985 | 0.007679 | YES |
| `mss-32b-q4` | OK | 115712 | 55296 | 32768 | 146.2 | 501.8 | 17.6 | 488 | 29093 | 0.008529 | YES |
| `mss-qwq-32b` | OK | 115712 | 55296 | 40960 | 411.1 | 430.4 | 11.8 | 3110 | 30145 | 0.023980 | NO |
| `mss-r1-14b` | OK | 212992 | 55296 | 55296 | 228.3 | 735.9 | 23.8 | 2903 | 20915 | 0.013318 | YES |
| `mss-r1-32b` | OK | 115712 | 55296 | 55296 | 805.8 | 303.6 | 4.6 | 2615 | 28595 | 0.047004 | YES |

## ⚠ Truncari detectate

Modele unde `prompt_eval_count >= ctx_used` (Ollama a trunchiat prompt-ul):
- **mss-r1-14b**: ctx_used=55296, prompt_real=55296
- **mss-r1-32b**: ctx_used=55296, prompt_real=55296

Cauza probabila: estimare initiala chars/3 a fost prea optimista (tokenizer-ul real produce mai multi tokens pe acest tip de continut). Solutie: creste safety in PROMPT_TOKENS_EST.
