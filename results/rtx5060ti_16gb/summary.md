# Benchmark summary: target = RTX 5060 Ti 16GB

## ⚠ EXECUTAT PE: `NVIDIA GeForce RTX 5060 Ti`

- **Proxy mode:** NU - rulat pe target real
- **VRAM target:** 16 GB
- **Pret cumparare:** $696 (eMAG nou (MSI Shadow 2X OC Plus))
- **Vast.ai $/hr:** $0.064
- **Timestamp:** 2026-04-20T12:06:52Z
- **Modele rulate:** 3 (OK: 1, FAILED: 2)

## Per-model metrics

| Model | Status | Wall (s) | Prompt eval (tok/s) | Output eval (tok/s) | Output tokens | VRAM peak (MB) | Cost/analiza ($) | Valid JSON |
|---|---|---:|---:|---:|---:|---:|---:|:---:|
| `mss-14b` | TIMEOUT | 600.0 | 0.0 | 0.0 | 0 | 12675 | 0.000000 | - |
| `mss-32b-q3` | TIMEOUT | 600.0 | 0.0 | 0.0 | 0 | 12579 | 0.000000 | - |
| `mss-r1-14b` | OK | 551.8 | 632.0 | 2.2 | 1085 | 12745 | 0.009810 | NO |

## Failures

- **mss-14b** (TIMEOUT): `Timeout dupa 600s`
- **mss-32b-q3** (TIMEOUT): `Timeout dupa 600s`
