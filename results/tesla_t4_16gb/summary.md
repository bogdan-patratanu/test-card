# Benchmark summary: target = Quadro RTX 5000 16GB

## ⚠ EXECUTAT PE: `Tesla T4`

- **Proxy mode:** DA
- **Target real (cumparat):** `Quadro RTX 5000 16GB`
- **Surogat folosit:** `Tesla T4`
- ⚠ **Atentie:** rezultatele reflecta perfomanta lui `Tesla T4`, NU a target-ului. Verifica daca surogatul e lower-bound real (mai slab pe compute SI bandwidth) sau optimist (mai puternic) inainte de a folosi cifrele pentru decizia de cumparare.
- **VRAM target:** 16 GB
- **Pret cumparare:** $346 (OLX Bucuresti 1500 lei (GodLike, Apr 2026))
- **Vast.ai $/hr:** $0.080
- **Timestamp:** 2026-04-22T04:16:48Z
- **Modele rulate:** 3 (OK: 1, FAILED: 2)

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
| `mss-14b-q4` | TIMEOUT | 54272 | 54272 | 0 | 900.0 | 0.0 | 0.0 | 0 | 11941 | 0.000000 | - |
| `mss-3b` | TIMEOUT | 394240 | 55296 | 0 | 900.0 | 0.0 | 0.0 | 0 | 4741 | 0.000000 | - |
| `mss-7b` | OK | 222208 | 55296 | 32768 | 70.8 | 598.7 | 14.1 | 157 | 9523 | 0.001574 | YES |

## Failures

- **mss-14b-q4** (TIMEOUT): `Timeout dupa 900s`
- **mss-3b** (TIMEOUT): `Timeout dupa 900s`
