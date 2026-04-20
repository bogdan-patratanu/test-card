# GPU benchmark suite pentru CFD price action analysis

Suite de scripturi auto-contained pentru benchmark de modele LLM (Ollama) pe diverse GPU-uri inchiriate de pe Vast.ai. Scopul: decizie informata pentru cumparare GPU vs. continuare pay-as-you-go.

## TL;DR pentru utilizatorul grabit

```bash
# Pe Vast.ai (zero setup, dupa ce ai facut clone):
git clone https://github.com/<USER>/<REPO>.git
cd <REPO>/test-card
./run.sh                         # SINGURUL script pe care il rulezi pe Vast

# Pe statia ta locala dupa ce ai rulat toate GPU-urile dorite:
git pull                         # ia rezultatele din repo
cd test-card
./compare-results.sh             # genereaza FINAL-REPORT.md
```

---

## 1. Setup ONE-TIME (5 minute, faci o singura data)

### 1.1. Repo GitHub PRIVAT pentru rezultate

1. Creeaza un repo PRIVAT pe GitHub (ex `gpu-bench-results`)
2. Push-eaza intregul folder `test-card/` (sau intregul `justTalk/` daca preferi)
3. Verifica ca branch-ul principal e `main`

### 1.2. GitHub Personal Access Token (PAT) pentru auto-push

1. Mergi la https://github.com/settings/personal-access-tokens
2. **"Generate new token"** -> **"Fine-grained personal access token"**
3. Setari:
   - **Token name:** `vast-bench-push`
   - **Expiration:** 90 days (sau cat dureaza experimentul)
   - **Repository access:** "Only select repositories" -> selecteaza repo-ul tau
   - **Permissions** -> Repository permissions:
     - **Contents**: Read and write
     - **Metadata**: Read-only (default)
4. **"Generate token"** -> COPIAZA token-ul (`github_pat_11ABCDE...`). NU il vei mai vedea.

### 1.3. Vast.ai - cont si template cu env var

1. Cont Vast.ai cu credit incarcat ($5-10 e suficient pentru toate testele)
2. **Account** -> **Templates** -> **"+ New Template"**:
   - **Image Path/Tag:** `nvidia/cuda:12.4.1-runtime-ubuntu22.04` (sau orice CUDA >= 12.0)
   - **Launch Mode:** SSH (entrypoint default)
   - **Disk space allocation:** **minim 100 GB** (modelele 32B Q4 ocupa ~20GB fiecare)
   - **Environment variables:**
     - `GITHUB_TOKEN` = `<token-ul tau de la pasul 1.2>`
   - Salveaza template-ul cu nume `gpu-bench`

### 1.4. SSH key pe Vast.ai

1. **Account** -> **Manage SSH Keys** -> adauga `~/.ssh/id_rsa.pub` de pe statia ta locala
2. (sau genereaza una noua cu `ssh-keygen -t ed25519`)

---

## 2. Filtre OBLIGATORII la creare instanta Vast.ai

In **"Create"** (search bar GPU):

| Filtru | Valoare |
|---|---|
| **Type** | On-Demand (pentru consistenta) |
| **Verified** | ✓ DA (fiabilitate maxima) |
| **GPU Model** | exact GPU-ul tintit (vezi tabelul de mai jos) |
| **Disk space** | min 100 GB |
| **Inet down** | min 500 Mbps (model 20GB se descarca in <5min) |
| **CUDA Vers** | min 12.0 |
| **Template** | template-ul tau cu `GITHUB_TOKEN` |

**Important:** la creare alegi prin filtru *exact* GPU-ul cerut de scriptul tau (sau surogatul mentionat in tabel).

---

## 3. Tabel central: GPU vizat -> Script -> Cum gasesti pe Vast.ai

| GPU vizat (cumparare) | Script | Pe Vast.ai? | Pret cumparare | Vast.ai $/hr aprox |
|---|---|---|---:|---:|
| **RTX 5060 Ti 16GB** | [01-test-rtx5060ti-16gb.sh](01-test-rtx5060ti-16gb.sh) | DA - filtreaza `RTX 5060 Ti` | $696 nou eMAG | $0.06 |
| **Quadro P5000 16GB** | [02-test-quadro-p5000-16gb.sh](02-test-quadro-p5000-16gb.sh) | NU -> SUROGAT: `Tesla P40 24GB` | $217-518 OLX | $0.10 (P40) |
| **Quadro RTX 5000 16GB** | [03-test-quadro-rtx5000-16gb.sh](03-test-quadro-rtx5000-16gb.sh) | NU -> SUROGATI (in ordinea preferintei): `Tesla T4 16GB` > `RTX 2080 Ti 11GB` > `Quadro RTX 6000 24GB` > `Titan RTX 24GB` | **$346** OLX Bucuresti (1500 lei) | $0.08-0.30 |
| **RTX 3090 24GB** | [06-test-rtx3090-24gb.sh](06-test-rtx3090-24gb.sh) | DA - filtreaza `RTX 3090` | $760 OLX Bucuresti | $0.16 |
| **Tesla V100 32GB** ⭐ | [08-test-v100-32gb.sh](08-test-v100-32gb.sh) | DA - filtreaza `V100-SXM2-32GB` sau `V100-PCIE-32GB` | $860 OLX Snagov | $0.21 |

⭐ = target principal cerut.

**Surogati:** placile de Quadro NU sunt pe Vast.ai. Folosim *cel mai apropiat datacenter card* ca proxy. Scriptul detecteaza automat ca rulezi pe surogat si marcheaza `proxy_mode: true` in raport.

Pentru **RTX 5000** in special, T4 e adesea epuizat. In aceasta ordine de preferinta:

| Surogat | Tip rezultat | Note |
|---|---|---|
| **Tesla T4 16GB** | LOWER BOUND (preferat) | Acelasi chip TU104, mai slab. RTX 5000 reala va fi ~30-40% mai rapida |
| **RTX 2080 Ti 11GB** | LOWER BOUND partial | TU102 mai puternic dar doar 11GB - 14B Q8 si 32B Q3 vor face OOM, doar R1-14B se va testa |
| **Quadro RTX 6000 24GB** | OPTIMIST upper bound | TU102 mai puternic + mai mult VRAM - RTX 5000 reala va fi mai lenta |
| **Titan RTX 24GB** | OPTIMIST upper bound | La fel ca RTX 6000 |

Pentru **P5000**: surogatul `Tesla P40 24GB` e *un pic optimist* (Pascal datacenter card mai puternic), dar singurul Pascal cu 16GB+ pe Vast. P5000 reala va fi marginal mai lenta.

### Pe Vast.ai, fluxul e mereu acelasi:

```bash
# pe instanta proaspata (dupa SSH):
git clone https://github.com/<USER>/<REPO>.git
cd <REPO>/test-card
./run.sh
```

`run.sh` ruleaza `nvidia-smi`, vede ce GPU detecteaza, mapeaza prin `_common/gpu_mapping.sh` la scriptul corect (din tabelul de mai sus), si il invoca. Tu nu alegi scriptul manual.

### Bonus: ruleaza in `tmux`/`screen` ca sa nu pierzi sesiunea

```bash
tmux new -s bench
./run.sh
# Ctrl+B, D pentru a detasa. Reattach cu: tmux attach -t bench
```

---

## 4. Modelele testate (filtrate per VRAM)

Toate cu `num_ctx=32768`, `temperature=0`, `seed=42` (determinist), KV cache `q8_0` cu FlashAttention pe Turing+ (Pascal cade automat la `f16`).

| Model | VRAM aprox | 16GB | 24GB | 32GB |
|---|---|:---:|:---:|:---:|
| `qwen2.5:14b-instruct-q8_0` | ~16GB | DA | DA | DA |
| `qwen2.5:32b-instruct-q3_K_S` | ~14.5GB | DA | DA | DA |
| `deepseek-r1:14b` (Q4) | ~9GB | DA | DA | DA |
| `qwen2.5:32b-instruct-q4_K_M` | ~19GB | NU | DA | DA |
| `deepseek-r1:32b` (Q4) | ~20GB | NU | DA | DA |
| `qwq:32b` (Q4) | ~20GB | NU | DA | DA |

Filtrarea se face in [_common/model_tiers.sh](_common/model_tiers.sh) (ajustabil).

### Estimari timp benchmark per GPU

- **16GB GPU** (RTX 5060 Ti, P5000, RTX 5000): 3 modele = **~30-60 min**
- **24GB GPU** (RTX 3090): 6 modele = **~60-120 min**
- **32GB GPU** (V100 32GB): 6 modele = **~60-120 min**

---

## 5. Workflow end-to-end

### A. Pe Vast.ai pentru fiecare GPU

```bash
# 1. Creezi instanta cu filtrul corect (vezi sectiunea 2-3)
# 2. SSH in instanta (foloseste comanda data de Vast.ai)
ssh -p <PORT> root@<HOST>

# 3. Verifica ca GITHUB_TOKEN e setat (din template)
echo $GITHUB_TOKEN | head -c 10  # ar trebui sa printeze "github_pat"

# 4. Clone si run
git clone https://github.com/<USER>/<REPO>.git
cd <REPO>/test-card
./run.sh

# 5. La final scriptul face git push automat. Output va arata:
#    [OK] Push reusit! Rezultatele sunt in repo.
#    [OK] Local fa: git pull

# 6. OPRESTE manual instanta din Vast.ai web UI (Destroy/Stop)
```

### B. Pe statia ta locala dupa toate instantele

```bash
cd ~/projectsB/justTalk
git pull
# results/v100_32gb/, results/rtx3090_24gb/ etc. apar automat

cd test-card
./compare-results.sh
# scrie FINAL-REPORT.md + FINAL-REPORT.json local (in .gitignore)
```

### C. Diagrama flux

```
   Local (statia ta)        GitHub repo PRIVAT      Vast.ai instanta GPU
   ─────────────────        ─────────────────       ────────────────────
       git push        ──>    main + test-card/  ──>     git clone
                                    ▲                       │
                                    │                       │
                                    │                    ./run.sh
                                    │                       │
                                    │                  benchmark...
                                    │                       │
                                    │                  results/<slug>/
                                    │                       │
       git pull        <──   results/<slug>/    <──     git push (auto)
            │
       compare-results.sh
            │
       FINAL-REPORT.md
```

---

## 6. Output structura

### Per GPU (creat pe Vast, push-uit in repo)

```
results/v100_32gb/
├── _system-info.json          # nvidia-smi parsed, lscpu, free, OS
├── _system-info.txt           # raw dump
├── _run-log.txt               # stdout/stderr complet
├── mss-14b-response.txt       # raspuns brut LLM
├── mss-14b-metrics.json       # toate metricile
├── mss-14b-nvsmi.csv          # log nvidia-smi 1Hz
├── mss-14b-raw-api-response.json
├── ... (per model)
├── summary.json               # agregat per GPU
└── summary.md                 # tabel readable
```

### Local dupa `compare-results.sh`

```
test-card/
├── FINAL-REPORT.md            # raport mare cu toate GPU-urile
└── FINAL-REPORT.json          # date structurate
```

`FINAL-REPORT.md` raspunde la "ce sa cumpar?":
- Tabel comparativ (GPU x model) sortat dupa cost/analiza
- Cost lunar pe Vast.ai vs cumparare la 50/100/300/1000 analize/zi
- Breakeven (luni) per scenariu
- Recomandare automata: "GPU X amortizeaza in Y luni la N analize/zi"
- Marcheaza explicit rezultatele cu `proxy_mode=true`

---

## 7. Cost estimat pentru tot benchmark-ul

| GPU | Vast $/hr | Timp estimat | Cost rulare |
|---|---:|---:|---:|
| RTX 5060 Ti 16GB | $0.06 | 30-60 min | $0.03-$0.06 |
| Tesla P40 (proxy P5000) | $0.10 | 30-60 min | $0.05-$0.10 |
| Surogat RTX 5000 (T4 / 2080 Ti / RTX 6000 / Titan RTX) | $0.08-0.30 | 30-60 min | $0.04-$0.30 |
| RTX 3090 24GB | $0.16 | 60-120 min | $0.16-$0.32 |
| Tesla V100 32GB | $0.21 | 60-120 min | $0.21-$0.42 |
| **TOTAL** | | | **~$0.50-$1.00** |

---

## 8. Tabel deal-uri OLX/eMag (Apr 2026, RON->USD la 4.33)

### eMag (placi NOI, garantie)

| Placa | VRAM | Pret RON | Pret USD | Comentariu |
|---|---:|---:|---:|---|
| MSI RTX 5060 Ti Shadow 2X OC Plus | 16GB | 3014 lei | $696 | cea mai ieftina noua 16GB |
| Asus RTX 5060 Ti Dual OC | 16GB | 3349 lei | $773 | alternativa noua |
| RTX 4080 Super (rar) | 16GB | 4050+ lei | $935+ | peste buget pentru ce ofera |

### OLX (second hand, fara garantie)

| Placa | VRAM | Pret USD | Locatie | Comentariu |
|---|---:|---:|---|---|
| Tesla V100 SXM2/PCIE | **32GB** | $860 | Snagov | server card, are nevoie de racire externa - target principal |
| RTX 3090 (Zotac/Asus) | 24GB | $760 | Bucuresti | best raport pret/perf |
| **Quadro RTX 5000 GDDR6** | **16GB** | **$346** (1500 lei) | Bucuresti Sector 6 | vendor "GodLike" Apr 2026 - [link OLX](https://www.olx.ro/d/oferta/placa-video-nvidia-16gb-gddr6-IDke7aQ.html), Turing TU104 |
| Quadro P5000 | 16GB | $217-518 | divers | pret variabil mult, atentie OEM |

---

## 9. Out of scope (mentionat scurt)

- **vLLM/llama.cpp direct** - doar Ollama (decizie din interviu - mai usor de comparat cu testele CPU existente)
- **Llama 3.1 70B / Qwen 32B Q8** - necesita ≥48GB VRAM, nicio placa target nu acopera
- **AMD RX 6800/7900** - Vast.ai nu ofera AMD verified, ROCm/Ollama instabil
- **Intel Arc A770** - aceeasi problema
- **RTX 4090, A6000** - peste buget realist (>$1500)
- **prompt.txt 62k tokens** - testam doar `prompt_test.txt` ~30k tokens (mai rapid si mai ieftin de evaluat)

---

## 10. Troubleshooting

### `nvidia-smi: command not found`

Ai inchiriat o instanta CPU-only. Distruge si recreeaza cu filtru GPU.

### `GITHUB_TOKEN nu e setat`

Ai uitat sa atasezi template-ul cu env var, sau template nu are `GITHUB_TOKEN`. Scriptul iti printeaza fallback - foloseste comanda `scp` sugerata pentru a copia tarball-ul manual.

### `OLLAMA_KEEP_ALIVE` ignorat (model nu se descarca)

Verifica `systemctl status ollama` si `cat /etc/systemd/system/ollama.service.d/override.conf`. Daca lipseste, scriptul a esuat la phase_1.

### Push esueaza cu "rejected (non-fast-forward)"

Doi colegi au rulat in paralel pe acelasi script. Improbabil pentru ca subdirectoarele `results/<gpu_slug>/` sunt unice per GPU. Daca apare, fa `cd repo && git pull --rebase && git push` manual din root.

### Model OOM (out of memory)

Scriptul marcheaza `status=OOM` si trece la urmatorul. Modelul respectiv depaseste VRAM-ul disponibil. Vezi `_common/model_tiers.sh` daca vrei sa modifici granitele.

### Model nu termina in 600s -> TIMEOUT

`status=TIMEOUT`, treci la urmatorul. GPU-ul e prea lent pentru acel model la 30k tokens (relevant! e info de business). Daca vrei sa cresti timeout: editeaza `TIMEOUT_PER_MODEL_SEC` in `_common/config.sh`.

---

## 11. Cum modific preturile (cand gasesc deal-uri mai bune)

Editeaza `_common/prices.sh` si push: tot raportul foloseste de aici.

```bash
# exemplu: actualizez pretul P5000
PRICES_quadro_p5000_16gb__purchase=300   # in loc de 380
git add _common/prices.sh
git commit -m "prices: P5000 actualizat la $300"
git push
```

La urmatorul `compare-results.sh` (LOCAL) noile preturi sunt folosite pentru breakeven.
