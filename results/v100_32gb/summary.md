# Benchmark summary: target = Tesla V100 32GB

## ⚠ EXECUTAT PE: `Tesla V100-SXM2-32GB`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 32 GB
- **Pret cumparare:** $860 (OLX Snagov (server card, necesita racire externa))
- **Vast.ai $/hr:** $0.210
- **Timestamp:** 2026-04-22T04:19:49Z
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
| `mss-14b` | OK | 148480 | 55296 | 32768 | 864.6 | 1035.0 | 29.2 | 22586 | 22634 | 0.050434 | NO |
| `mss-14b-q4` | OK | 239616 | 55296 | 32768 | 357.0 | 970.3 | 33.6 | 9808 | 16602 | 0.020827 | YES |
| `mss-32b-q3` | TIMEOUT | 119808 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 23988 | 0.000000 | - |
| `mss-32b-q4` | OK | 115712 | 55296 | 32768 | 141.7 | 507.8 | 19.5 | 1262 | 29094 | 0.008267 | YES |
| `mss-3b` | TIMEOUT | 1031168 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 5688 | 0.000000 | - |
| `mss-7b` | OK | 859136 | 55296 | 32768 | 321.3 | 2132.1 | 58.5 | 15547 | 10894 | 0.018745 | YES |
| `mss-qwq-32b` | OK | 115712 | 55296 | 40960 | 756.5 | 380.8 | 9.7 | 6175 | 30144 | 0.044129 | NO |
| `mss-r1-14b` | OK | 212992 | 55296 | 55296 | 114.4 | 731.8 | 25.2 | 591 | 20916 | 0.006671 | YES |
| `mss-r1-32b` | OK | 115712 | 55296 | 55296 | 639.4 | 213.5 | 2.8 | 1038 | 28588 | 0.037298 | YES |

## ⚠ Truncari detectate

Modele unde `prompt_eval_count >= ctx_used` (Ollama a trunchiat prompt-ul):
- **mss-r1-14b**: ctx_used=55296, prompt_real=55296
- **mss-r1-32b**: ctx_used=55296, prompt_real=55296

Cauza probabila: estimare initiala chars/3 a fost prea optimista (tokenizer-ul real produce mai multi tokens pe acest tip de continut). Solutie: creste safety in PROMPT_TOKENS_EST.

## Failures

- **mss-32b-q3** (TIMEOUT): `Timeout dupa 900s`
- **mss-3b** (TIMEOUT): `Timeout dupa 900s`
