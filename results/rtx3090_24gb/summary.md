# Benchmark summary: target = RTX 3090 24GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 3090`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 24 GB
- **Pret cumparare:** $760 (OLX Bucuresti (Zotac/Asus 24GB))
- **Vast.ai $/hr:** $0.160
- **Timestamp:** 2026-04-20T13:40:30Z
- **Modele rulate:** 6 (OK: 4, FAILED: 2)

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
| `mss-14b` | OK | 61440 | 55296 | 32768 | 134.2 | 1435.5 | 23.4 | 2146 | 21030 | 0.005963 | YES |
| `mss-32b-q3` | OK | 54272 | 54272 | 32768 | 117.3 | 709.8 | 9.4 | 475 | 21312 | 0.005212 | YES |
| `mss-32b-q4` | OK | 50176 | 50176 | 32768 | 191.6 | 573.7 | 4.0 | 489 | 21206 | 0.008516 | YES |
| `mss-qwq-32b` | TIMEOUT | 50176 | 50176 | 0 | 900.0 | 0.0 | 0.0 | 0 | 20174 | 0.000000 | - |
| `mss-r1-14b` | OK | 125952 | 55296 | 55296 | 314.9 | 1055.0 | 14.3 | 2785 | 18838 | 0.013995 | YES |
| `mss-r1-32b` | TIMEOUT | 50176 | 50176 | 0 | 900.0 | 0.0 | 0.0 | 0 | 19366 | 0.000000 | - |

## ⚠ Truncari detectate

Modele unde `prompt_eval_count >= ctx_used` (Ollama a trunchiat prompt-ul):
- **mss-r1-14b**: ctx_used=55296, prompt_real=55296

Cauza probabila: estimare initiala chars/3 a fost prea optimista (tokenizer-ul real produce mai multi tokens pe acest tip de continut). Solutie: creste safety in PROMPT_TOKENS_EST.

## Failures

- **mss-qwq-32b** (TIMEOUT): `Timeout dupa 900s`
- **mss-r1-32b** (TIMEOUT): `Timeout dupa 900s`
