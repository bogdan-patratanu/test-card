# Benchmark summary: target = RTX 3090 24GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 3090`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 24 GB
- **Pret cumparare:** $760 (OLX Bucuresti (Zotac/Asus 24GB))
- **Vast.ai $/hr:** $0.160
- **Timestamp:** 2026-04-22T04:22:03Z
- **Modele rulate:** 9 (OK: 4, FAILED: 5)

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
| `mss-14b` | TIMEOUT | 61440 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 21028 | 0.000000 | - |
| `mss-14b-q4` | OK | 152576 | 55296 | 32768 | 547.6 | 1493.7 | 29.9 | 14881 | 14998 | 0.024337 | YES |
| `mss-32b-q3` | OK | 54272 | 54272 | 32768 | 167.1 | 662.8 | 5.7 | 577 | 21308 | 0.007425 | YES |
| `mss-32b-q4` | OK | 50176 | 50176 | 32768 | 483.5 | 476.6 | 1.6 | 628 | 21202 | 0.021490 | YES |
| `mss-3b` | TIMEOUT | 731136 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 4928 | 0.000000 | - |
| `mss-7b` | TIMEOUT | 559104 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 9694 | 0.000000 | - |
| `mss-qwq-32b` | TIMEOUT | 50176 | 50176 | 0 | 900.0 | 0.0 | 0.0 | 0 | 20170 | 0.000000 | - |
| `mss-r1-14b` | OK | 125952 | 55296 | 55296 | 215.2 | 999.4 | 9.4 | 1369 | 18832 | 0.009566 | YES |
| `mss-r1-32b` | TIMEOUT | 50176 | 50176 | 0 | 900.0 | 0.0 | 0.0 | 0 | 19362 | 0.000000 | - |

## ⚠ Truncari detectate

Modele unde `prompt_eval_count >= ctx_used` (Ollama a trunchiat prompt-ul):
- **mss-r1-14b**: ctx_used=55296, prompt_real=55296

Cauza probabila: estimare initiala chars/3 a fost prea optimista (tokenizer-ul real produce mai multi tokens pe acest tip de continut). Solutie: creste safety in PROMPT_TOKENS_EST.

## Failures

- **mss-14b** (TIMEOUT): `Timeout dupa 900s`
- **mss-3b** (TIMEOUT): `Timeout dupa 900s`
- **mss-7b** (TIMEOUT): `Timeout dupa 900s`
- **mss-qwq-32b** (TIMEOUT): `Timeout dupa 900s`
- **mss-r1-32b** (TIMEOUT): `Timeout dupa 900s`
