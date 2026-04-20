# Benchmark summary: target = Quadro RTX 5000 16GB

## ⚠ EXECUTAT PE: `NVIDIA RTX A4000`

- **Proxy mode:** DA
- **Target real (cumparat):** `Quadro RTX 5000 16GB`
- **Surogat folosit:** `NVIDIA RTX A4000`
- ⚠ **Atentie:** rezultatele reflecta perfomanta lui `NVIDIA RTX A4000`, NU a target-ului. Verifica daca surogatul e lower-bound real (mai slab pe compute SI bandwidth) sau optimist (mai puternic) inainte de a folosi cifrele pentru decizia de cumparare.
- **VRAM target:** 16 GB
- **Pret cumparare:** $346 (OLX Bucuresti 1500 lei (GodLike, Apr 2026))
- **Vast.ai $/hr:** $0.080
- **Timestamp:** 2026-04-20T14:10:32Z
- **Modele rulate:** 3 (OK: 0, FAILED: 3)

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
| `mss-14b` | PROMPT_TOO_LARGE | 0 | 0 | 0 | 0.0 | 0.0 | 0.0 | 0 | 0 | 0.000000 | - |
| `mss-32b-q3` | PROMPT_TOO_LARGE | 0 | 0 | 0 | 0.0 | 0.0 | 0.0 | 0 | 0 | 0.000000 | - |
| `mss-r1-14b` | TIMEOUT | 37888 | 37888 | 0 | 900.0 | 0.0 | 0.0 | 0 | 12463 | 0.000000 | - |

## Failures

- **mss-14b** (PROMPT_TOO_LARGE): VRAM-ul cardului (16376MB) nu permite ctx suficient pentru acest model + prompt. Detalii: `max_ctx=0, needed=37251, prompt_tokens_est=35203`
- **mss-32b-q3** (PROMPT_TOO_LARGE): VRAM-ul cardului (16376MB) nu permite ctx suficient pentru acest model + prompt. Detalii: `max_ctx=0, needed=37251, prompt_tokens_est=35203`
- **mss-r1-14b** (TIMEOUT): `Timeout dupa 900s`
