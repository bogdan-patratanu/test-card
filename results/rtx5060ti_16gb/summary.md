# Benchmark summary: target = RTX 5060 Ti 16GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 5060 Ti`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 16 GB
- **Pret cumparare:** $696 (eMAG nou (MSI Shadow 2X OC Plus))
- **Vast.ai $/hr:** $0.064
- **Timestamp:** 2026-04-20T14:27:27Z
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
| `mss-r1-14b` | PROMPT_TOO_LARGE | 36864 | 0 | 0 | 0.0 | 0.0 | 0.0 | 0 | 0 | 0.000000 | - |

## Failures

- **mss-14b** (PROMPT_TOO_LARGE): VRAM-ul cardului (16311MB) nu permite ctx suficient pentru acest model + prompt. Detalii: `max_ctx=0, needed=37251, prompt_tokens_est=35203`
- **mss-32b-q3** (PROMPT_TOO_LARGE): VRAM-ul cardului (16311MB) nu permite ctx suficient pentru acest model + prompt. Detalii: `max_ctx=0, needed=37251, prompt_tokens_est=35203`
- **mss-r1-14b** (PROMPT_TOO_LARGE): VRAM-ul cardului (16311MB) nu permite ctx suficient pentru acest model + prompt. Detalii: `max_ctx=36864, needed=37251, prompt_tokens_est=35203`
