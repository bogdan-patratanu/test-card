# Benchmark summary: target = Tesla V100 32GB

## ⚠ EXECUTAT PE: `Tesla V100-SXM2-32GB`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 32 GB
- **Pret cumparare:** $860 (OLX Snagov (server card, necesita racire externa))
- **Vast.ai $/hr:** $0.210
- **Timestamp:** 2026-04-22T02:59:08Z
- **Modele rulate:** 9 (OK: 8, FAILED: 1)

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
| `mss-14b` | OK | 148480 | 55296 | 32768 | 120.5 | 1037.8 | 28.0 | 2209 | 22632 | 0.007032 | YES |
| `mss-14b-q4` | OK | 239616 | 55296 | 32768 | 107.2 | 975.3 | 33.9 | 2203 | 16602 | 0.006251 | YES |
| `mss-32b-q3` | OK | 119808 | 55296 | 32768 | 100.6 | 514.9 | 16.4 | 485 | 23986 | 0.005869 | YES |
| `mss-32b-q4` | OK | 115712 | 55296 | 32768 | 97.4 | 510.3 | 19.8 | 488 | 29094 | 0.005681 | YES |
| `mss-3b` | OK | 1031168 | 55296 | 32768 | 16.8 | 3699.7 | 121.8 | 493 | 5686 | 0.000983 | YES |
| `mss-7b` | OK | 859136 | 55296 | 32768 | 29.1 | 2139.2 | 58.6 | 488 | 10894 | 0.001695 | YES |
| `mss-qwq-32b` | OK | 115712 | 55296 | 40960 | 735.8 | 385.1 | 9.7 | 5998 | 30144 | 0.042920 | NO |
| `mss-r1-14b` | OK | 212992 | 55296 | 55296 | 198.3 | 736.0 | 25.5 | 2903 | 20916 | 0.011568 | YES |
| `mss-r1-32b` | TIMEOUT | 115712 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 28588 | 0.000000 | - |

## ⚠ Truncari detectate

Modele unde `prompt_eval_count >= ctx_used` (Ollama a trunchiat prompt-ul):
- **mss-r1-14b**: ctx_used=55296, prompt_real=55296

Cauza probabila: estimare initiala chars/3 a fost prea optimista (tokenizer-ul real produce mai multi tokens pe acest tip de continut). Solutie: creste safety in PROMPT_TOKENS_EST.

## Failures

- **mss-r1-32b** (TIMEOUT): `Timeout dupa 900s`
