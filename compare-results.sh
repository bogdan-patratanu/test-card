#!/usr/bin/env bash
# =============================================================================
# compare-results.sh - aggregator LOCAL (ruleaza pe statia ta dupa git pull)
# Citeste results/*/summary.json si emite:
#   - FINAL-REPORT.md  (tabel sortat dupa wall-time + recomandari)
#   - FINAL-REPORT.json (date structurate pentru orice prelucrare ulterioara)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERR] python3 e necesar pentru compare-results.sh"
    exit 1
fi

# Source config pentru tunables
source _common/config.sh
source _common/prices.sh

if [[ ! -d results ]]; then
    echo "[ERR] Directorul results/ nu exista. Ai rulat git pull dupa benchmark-uri?"
    exit 1
fi

# Numara cate summary-uri avem
SUMMARY_COUNT=$(find results -mindepth 2 -maxdepth 2 -name "summary.json" 2>/dev/null | wc -l)
if (( SUMMARY_COUNT == 0 )); then
    echo "[ERR] Nicio rulare in results/ (nu am gasit niciun summary.json)."
    echo "      Verifica: ls results/*/summary.json"
    exit 1
fi
echo "[INFO] $SUMMARY_COUNT GPU summary-uri gasite"

python3 - "$EXCHANGE_RATE_RON_USD" <<'PYEOF'
import json, glob, os, sys
from datetime import datetime, timezone

EXCHANGE_RATE = float(sys.argv[1])
ANALYSES_PER_DAY_SCENARIOS = [50, 100, 300, 1000]

# ---------------------------------------------------------------------------
# Load all summaries
# ---------------------------------------------------------------------------
summaries = []
for path in sorted(glob.glob("results/*/summary.json")):
    with open(path) as f:
        s = json.load(f)
        s["_summary_path"] = path
        summaries.append(s)

if not summaries:
    print("[ERR] No summaries loaded")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Flatten: list of (gpu, model) tuples for the big table
# ---------------------------------------------------------------------------
import hashlib, re
rows = []
for s in summaries:
    results_dir = os.path.dirname(s["_summary_path"])
    for m in s.get("models", []):
        cn = m.get("model")
        # Citim raspunsul brut daca exista
        resp_path = os.path.join(results_dir, f"{cn}-response.txt")
        resp_text = ""
        if os.path.exists(resp_path):
            try:
                with open(resp_path, encoding="utf-8", errors="replace") as f:
                    resp_text = f.read()
            except Exception:
                resp_text = ""
        rows.append({
            "gpu_key": s["gpu_key"],
            "target_gpu": s["target_gpu"],
            "detected_gpu": s["detected_gpu"],
            "detected_vram_total_mb": m.get("detected_vram_total_mb", 0),
            "proxy_mode": s["proxy_mode"],
            "purchase_price_usd": s["purchase_price_usd"],
            "vast_price_per_hour_usd": s["vast_price_per_hour_usd"],
            "model": cn,
            "model_base": m.get("model_base"),
            "model_size_mb": m.get("model_size_mb", 0),
            "status": m.get("status"),
            "wall_time_sec": m.get("wall_time_sec", 0),
            "load_duration_sec": m.get("load_duration_sec", 0),
            "prompt_eval_duration_sec": m.get("prompt_eval_duration_sec", 0),
            "eval_duration_sec": m.get("eval_duration_sec", 0),
            "total_duration_sec": m.get("total_duration_sec", 0),
            "prompt_eval_rate": m.get("prompt_eval_rate_tok_per_sec", 0),
            "eval_rate": m.get("eval_rate_tok_per_sec", 0),
            "eval_count": m.get("eval_count", 0),
            "vram_peak_mb": m.get("vram_peak_mb", 0),
            "cost_per_analysis_usd": m.get("cost_per_analysis_usd", 0),
            "response_is_valid_json": m.get("response_is_valid_json"),
            "response_chars": m.get("response_chars", 0),
            "response_text": resp_text,
            "ctx_max_fits": m.get("ctx_max_fits", 0),
            "ctx_used": m.get("ctx_used", 0),
            "prompt_tokens_real": m.get("prompt_tokens_real", 0),
            "prompt_truncated": m.get("prompt_truncated", False),
            "ollama_kv_cache_type": m.get("ollama_kv_cache_type", "?"),
            "ollama_flash_attention": m.get("ollama_flash_attention", "?"),
        })

# ---------------------------------------------------------------------------
# Helpers pentru analiza calitativa raspuns
# ---------------------------------------------------------------------------

# Field-urile-cheie pe care le asteptam in JSON-ul ideal (din schema prompt_test.txt
# - sectiunea "## Output Format"). Folosit pentru "schema coverage".
EXPECTED_TOP_LEVEL_FIELDS = [
    "pair",
    "analysis_timestamp",
    "overall_bias",
    "bias_confidence",
    "market_regime",
    "session_context",
    "timeframe_analysis",
    "contra_analysis",
    "confluence_factors",
    "data_quality",
    "trade",
    "setup_quality_score",
    "analysis_summary",
]

# Sinonime acceptate (modelele mici/quantizate variaza usor in naming).
# Cheile de aici trebuie sa fie EXACT cele din EXPECTED_TOP_LEVEL_FIELDS.
FIELD_ALIASES = {
    "pair":                 ["pair", "instrument", "symbol"],
    "analysis_timestamp":   ["analysis_timestamp", "current_time", "timestamp", "analysis_time"],
    "overall_bias":         ["overall_bias", "bias", "direction", "trend_bias"],
    "bias_confidence":      ["bias_confidence", "confidence", "conviction", "confidence_score"],
    "market_regime":        ["market_regime", "regime", "market_state"],
    "session_context":      ["session_context", "session", "session_info"],
    "timeframe_analysis":   ["timeframe_analysis", "timeframes", "tf_notes", "timeframe_notes"],
    "contra_analysis":      ["contra_analysis", "counter_analysis", "opposing_analysis"],
    "confluence_factors":   ["confluence_factors", "confluences", "confluence"],
    "data_quality":         ["data_quality", "data_check", "quality"],
    "trade":                ["trade", "trade_setup", "setup", "trade_recommendation", "trade_plan"],
    "setup_quality_score":  ["setup_quality_score", "setup_score", "quality_score", "score"],
    "analysis_summary":     ["analysis_summary", "summary", "analysis", "reasoning"],
}

def strip_code_fence(s):
    s = s.strip()
    s = re.sub(r"^```(?:json)?\s*", "", s)
    s = re.sub(r"\s*```\s*$", "", s)
    return s.strip()

def try_parse_json(text):
    """Incearca extragere JSON din text. Returneaza dict sau None."""
    if not text:
        return None
    cleaned = strip_code_fence(text)
    try:
        return json.loads(cleaned)
    except Exception:
        # Incearca sa extragem primul {...} balansat
        first = cleaned.find("{")
        last  = cleaned.rfind("}")
        if first >= 0 and last > first:
            try:
                return json.loads(cleaned[first:last+1])
            except Exception:
                pass
    return None

def schema_coverage(parsed):
    """Returneaza (covered_count, total, list_present, list_missing)."""
    if not isinstance(parsed, dict):
        return (0, len(EXPECTED_TOP_LEVEL_FIELDS), [], EXPECTED_TOP_LEVEL_FIELDS[:])
    keys_lower = {k.lower() for k in parsed.keys()}
    present, missing = [], []
    for canonical in EXPECTED_TOP_LEVEL_FIELDS:
        aliases = FIELD_ALIASES.get(canonical, [canonical])
        if any(a.lower() in keys_lower for a in aliases):
            present.append(canonical)
        else:
            missing.append(canonical)
    return (len(present), len(EXPECTED_TOP_LEVEL_FIELDS), present, missing)

def response_fingerprint(text, n=200):
    """Hash scurt pe primele n chars normalizate, ca sa identificam raspunsuri identice."""
    if not text:
        return "—"
    cleaned = re.sub(r"\s+", " ", strip_code_fence(text)).strip()[:n]
    return hashlib.sha256(cleaned.encode("utf-8")).hexdigest()[:8]

def response_snippet(text, n=240):
    if not text:
        return "(gol)"
    cleaned = strip_code_fence(text).replace("\n", " ").replace("|", "\\|")
    return cleaned[:n] + ("..." if len(cleaned) > n else "")

def extract_action(parsed):
    """Returneaza valoarea pentru 'action' (poate fi top-level sau nested in 'trade')."""
    if not isinstance(parsed, dict):
        return None
    # Prioritate 1: nested in 'trade' / 'trade_setup' (formatul actual al prompt-ului)
    for tkey in ("trade", "trade_setup", "setup", "trade_plan"):
        tv = parsed.get(tkey)
        if isinstance(tv, dict):
            for ak in ("action", "decision", "side", "direction"):
                if ak in tv and tv[ak] is not None:
                    return str(tv[ak]).lower()
    # Prioritate 2: top-level
    for k in parsed.keys():
        if k.lower() in {"action", "decision", "recommendation", "overall_bias"}:
            v = parsed[k]
            if isinstance(v, dict):
                for k2 in ("type", "value", "side"):
                    if k2 in v:
                        return str(v[k2]).lower()
                return str(v)[:30]
            return str(v).lower() if v is not None else None
    return None

def extract_confidence(parsed):
    """Cauta confidence top-level sau bias_confidence (formatul actual)."""
    if not isinstance(parsed, dict):
        return None
    for k in parsed.keys():
        if k.lower() in {"bias_confidence", "confidence", "conviction", "confidence_score"}:
            v = parsed[k]
            if v is None:
                continue
            try:
                return float(v)
            except Exception:
                return v
    # Fallback: setup_quality_score (numeric, sugereaza calitate)
    if "setup_quality_score" in parsed and parsed["setup_quality_score"] is not None:
        try:
            return float(parsed["setup_quality_score"])
        except Exception:
            return parsed["setup_quality_score"]
    return None

# ---------------------------------------------------------------------------
# Per-GPU best-model selection (pentru recomandari)
# Criteriu: model OK + valid JSON + wall_time minim
# ---------------------------------------------------------------------------
def best_model_for_gpu(s):
    candidates = [m for m in s.get("models", [])
                  if m.get("status") == "OK" and m.get("response_is_valid_json")]
    if not candidates:
        candidates = [m for m in s.get("models", []) if m.get("status") == "OK"]
    if not candidates:
        return None
    return min(candidates, key=lambda m: m.get("wall_time_sec", 1e9))

# ---------------------------------------------------------------------------
# Build FINAL-REPORT.md
# ---------------------------------------------------------------------------
md = []
md.append("# FINAL REPORT - GPU benchmark pentru CFD price action analysis")
md.append("")
md.append(f"_Generat: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}_")
md.append(f"_Curs: 1 USD = {EXCHANGE_RATE} RON_")
md.append("")
md.append(f"## Sumar")
md.append("")
md.append(f"- **GPU-uri testate:** {len(summaries)}")
md.append(f"- **Total runs:** {len(rows)} (OK: {sum(1 for r in rows if r['status']=='OK')})")
md.append("")

# Lista GPU-uri rulate
md.append("### GPU-uri analizate")
md.append("")
md.append("| GPU vizat | Detectat pe Vast | Proxy? | Pret cumparare | Modele OK | Cel mai bun model |")
md.append("|---|---|:---:|---:|:---:|---|")
for s in summaries:
    proxy = "DA" if s["proxy_mode"] else "nu"
    n_ok = s["models_ok"]; n_total = s["models_tested"]
    best = best_model_for_gpu(s)
    best_str = f"`{best['model']}` ({best['wall_time_sec']:.1f}s)" if best else "-"
    md.append(f"| {s['target_gpu']} | `{s['detected_gpu']}` | {proxy} | ${s['purchase_price_usd']:.0f} | {n_ok}/{n_total} | {best_str} |")
md.append("")

ok_rows = sorted([r for r in rows if r["status"] == "OK"],
                 key=lambda r: r["wall_time_sec"])
fail_rows = [r for r in rows if r["status"] != "OK"]

# Group rows by model_base (sau model custom name) - folosit in mai multe sectiuni
from collections import defaultdict
by_model = defaultdict(list)
for r in rows:
    key = r["model_base"] or r["model"]
    by_model[key].append(r)

# Sorteaza modelele dupa marime (dimens model)
def model_size_key(rs):
    sizes = [r.get("model_size_mb", 0) for r in rs if r.get("model_size_mb", 0) > 0]
    return min(sizes) if sizes else 0

# Lista GPU-uri unice (pentru matrix headers)
all_gpus_ordered = []
seen_gpu_keys = set()
for s in summaries:
    if s["gpu_key"] not in seen_gpu_keys:
        seen_gpu_keys.add(s["gpu_key"])
        all_gpus_ordered.append({
            "gpu_key": s["gpu_key"],
            "label": s["detected_gpu"] or s["target_gpu"],
            "proxy": s["proxy_mode"],
            "target": s["target_gpu"],
        })

# ============================================================
# MATRICE TIMP DE RASPUNS (model x GPU) - vedere de ansamblu
# ============================================================
md.append("## Matrice timp raspuns (wall-time in secunde) - model x GPU")
md.append("")
md.append("Vedere rapida: pentru fiecare combinatie model+GPU, cat a durat un singur cold-run (load + prompt eval + generation).")
md.append("Cellula goala = nu s-a rulat. `n/a` = a esuat (PROMPT_TOO_LARGE / OOM / TIMEOUT).")
md.append("")

# Header: Model | GPU1 | GPU2 | ...
header = "| Model |"
sep = "|---|"
for g in all_gpus_ordered:
    short = g["label"]
    if g["proxy"]:
        short += " *(proxy)*"
    header += f" {short} |"
    sep += "---:|"
md.append(header)
md.append(sep)

# Pentru fiecare model: o linie cu wall_time per GPU
for model_base in sorted(by_model.keys(), key=lambda k: model_size_key(by_model[k])):
    model_rows = by_model[model_base]
    by_gpu = {r["gpu_key"]: r for r in model_rows}
    line = f"| `{model_base}` |"
    # gaseste cel mai rapid OK pe acest model (pt highlight)
    ok_for_this = [r for r in model_rows if r["status"] == "OK"]
    fastest_key = min(ok_for_this, key=lambda r: r["wall_time_sec"])["gpu_key"] if ok_for_this else None
    for g in all_gpus_ordered:
        r = by_gpu.get(g["gpu_key"])
        if r is None:
            line += " - |"
        elif r["status"] != "OK":
            line += f" n/a (`{r['status']}`) |"
        else:
            cell = f"{r['wall_time_sec']:.1f}s"
            if g["gpu_key"] == fastest_key:
                cell = f"**{cell}**"
            line += f" {cell} |"
    md.append(line)
md.append("")
md.append("_Bold = cel mai rapid GPU pentru acel model._")
md.append("")

# Matrice tok/s pentru context (cat de eficient prelucreaza modelul, independent de prompt size)
md.append("### Matrice viteza generare (eval tok/s) - model x GPU")
md.append("")
md.append("Aceasta arata viteza pura de generare, **fara timpul de incarcare model si fara prompt eval**. Util ca sa vezi capacitatea bruta a placii pe acel model.")
md.append("")
header = "| Model |"
sep = "|---|"
for g in all_gpus_ordered:
    short = g["label"]
    if g["proxy"]:
        short += " *(proxy)*"
    header += f" {short} |"
    sep += "---:|"
md.append(header)
md.append(sep)

for model_base in sorted(by_model.keys(), key=lambda k: model_size_key(by_model[k])):
    model_rows = by_model[model_base]
    by_gpu = {r["gpu_key"]: r for r in model_rows}
    line = f"| `{model_base}` |"
    ok_for_this = [r for r in model_rows if r["status"] == "OK" and r["eval_rate"] > 0]
    fastest_key = max(ok_for_this, key=lambda r: r["eval_rate"])["gpu_key"] if ok_for_this else None
    for g in all_gpus_ordered:
        r = by_gpu.get(g["gpu_key"])
        if r is None:
            line += " - |"
        elif r["status"] != "OK":
            line += " n/a |"
        else:
            cell = f"{r['eval_rate']:.1f}"
            if g["gpu_key"] == fastest_key:
                cell = f"**{cell}**"
            line += f" {cell} |"
    md.append(line)
md.append("")

# ============================================================
# VIEW NOU: PER-MODEL COMPARISON
# Pentru fiecare model: vezi cum a raspuns fiecare GPU care l-a putut rula.
# ============================================================
md.append("## Comparatie PER MODEL (cum a performat fiecare GPU pe acelasi model)")
md.append("")
md.append("Pentru fiecare LLM, vezi toate GPU-urile care l-au rulat. Util pentru:")
md.append("- A vedea daca un model anume raspunde corect (JSON valid) pe toate cardurile")
md.append("- A compara viteza pe acelasi model intre carduri")
md.append("- A vedea unde un GPU nu poate rula modelul (PROMPT_TOO_LARGE / OOM / TIMEOUT)")
md.append("")

# Pre-calc analiza calitativa per row (ca sa folosim si in verdict si in sectiunea dedicata)
for r in rows:
    parsed = try_parse_json(r["response_text"])
    r["_parsed"] = parsed
    r["_schema_present"], r["_schema_total"], r["_schema_present_list"], r["_schema_missing_list"] = schema_coverage(parsed)
    r["_fingerprint"] = response_fingerprint(r["response_text"])
    r["_action"] = extract_action(parsed)
    r["_confidence"] = extract_confidence(parsed)

for model_base in sorted(by_model.keys(), key=lambda k: model_size_key(by_model[k])):
    model_rows = by_model[model_base]
    sample = model_rows[0]
    msize = sample.get("model_size_mb", 0)
    
    md.append(f"### `{model_base}` (~{msize}MB pe disc)")
    md.append("")
    md.append("**Breakdown timpi raspuns** (load = incarcare model in VRAM, prompt = procesare prompt input, gen = generare output):")
    md.append("")
    md.append("| GPU (real) | Status | Load (s) | Prompt eval (s) | Gen (s) | **Wall total (s)** | Prompt tok/s | Gen tok/s | Output tok |")
    md.append("|---|:---:|---:|---:|---:|---:|---:|---:|---:|")

    sorted_rows = sorted(model_rows, key=lambda r: (
        0 if r["status"] == "OK" else 1,
        r.get("wall_time_sec", 1e9) if r["status"] == "OK" else 0
    ))

    for r in sorted_rows:
        gpu_label = r["detected_gpu"] or r["target_gpu"]
        if r["proxy_mode"]:
            gpu_label = f"{gpu_label} *(proxy pt {r['target_gpu']})*"
        if r["status"] == "OK":
            md.append(f"| {gpu_label} | OK | {r['load_duration_sec']:.1f} | "
                      f"{r['prompt_eval_duration_sec']:.1f} | {r['eval_duration_sec']:.1f} | "
                      f"**{r['wall_time_sec']:.1f}** | "
                      f"{r['prompt_eval_rate']:.0f} | {r['eval_rate']:.1f} | "
                      f"{r['eval_count']} |")
        else:
            md.append(f"| {gpu_label} | **{r['status']}** | - | - | - | "
                      f"{r['wall_time_sec']:.1f} | - | - | - |")
    md.append("")
    md.append("**Calitate raspuns + resurse**:")
    md.append("")
    md.append("| GPU (real) | Status | ctx max | ctx used | Prompt tok | VRAM peak | JSON | Schema | Resp len |")
    md.append("|---|:---:|---:|---:|---:|---:|:---:|:---:|---:|")

    for r in sorted_rows:
        gpu_label = r["detected_gpu"] or r["target_gpu"]
        if r["proxy_mode"]:
            gpu_label = f"{gpu_label} *(proxy pt {r['target_gpu']})*"
        is_json_v = r["response_is_valid_json"]
        is_json = "✓" if is_json_v is True else ("✗" if is_json_v is False else "-")
        schema_str = f"{r['_schema_present']}/{r['_schema_total']}" if r["status"] == "OK" else "-"
        if r["status"] == "OK":
            md.append(f"| {gpu_label} | OK | {r['ctx_max_fits']} | {r['ctx_used']} | "
                      f"{r['prompt_tokens_real']} | {r['vram_peak_mb']} | "
                      f"{is_json} | {schema_str} | {r['response_chars']} |")
        else:
            md.append(f"| {gpu_label} | **{r['status']}** | {r['ctx_max_fits']} | {r['ctx_used']} | "
                      f"- | {r['vram_peak_mb']} | - | - | - |")
    md.append("")

    # ====== VERDICT per model ======
    ok = [r for r in sorted_rows if r["status"] == "OK"]
    skipped = [r for r in sorted_rows if r["status"] != "OK"]
    if not ok:
        md.append("**Verdict:** Niciun GPU n-a putut rula acest model cu prompt-ul actual.")
        if skipped:
            md.append(f"- {len(skipped)} card(uri) au esuat (PROMPT_TOO_LARGE / OOM).")
        md.append("")
        continue

    # Filtreaza la "raspuns valid + schema OK" (>=50% campuri prezente)
    valid_ok = [r for r in ok if r["response_is_valid_json"] and r["_schema_present"] >= r["_schema_total"] // 2]
    if not valid_ok:
        # Relaxam: macar JSON valid
        valid_ok = [r for r in ok if r["response_is_valid_json"]]
    if not valid_ok:
        # Si mai relaxat: orice OK
        valid_ok = ok

    fastest = min(valid_ok, key=lambda r: r["wall_time_sec"])
    cheapest_buy = min(valid_ok, key=lambda r: r["purchase_price_usd"])

    def label(r):
        s = r["detected_gpu"]
        if r["proxy_mode"]:
            s = f"{s} *(proxy pt {r['target_gpu']})*"
        return s

    md.append("**Verdict:**")
    md.append(f"- **Cel mai rapid (raspuns valid):** {label(fastest)} - {fastest['wall_time_sec']:.1f}s, {fastest['eval_rate']:.1f} tok/s, schema {fastest['_schema_present']}/{fastest['_schema_total']}")
    if cheapest_buy["gpu_key"] != fastest["gpu_key"]:
        md.append(f"- **Cel mai ieftin de cumparat (raspuns valid):** {label(cheapest_buy)} - ${cheapest_buy['purchase_price_usd']:.0f}, {cheapest_buy['wall_time_sec']:.1f}s")

    # Recomandare bazata pe valoarea adaugata: daca cheapest_buy si fastest dau acelasi raspuns,
    # nu are sens sa cumperi mai scump.
    if cheapest_buy["_fingerprint"] == fastest["_fingerprint"] and cheapest_buy["gpu_key"] != fastest["gpu_key"]:
        md.append(f"- **Recomandare:** raspuns IDENTIC pe {label(cheapest_buy)} si {label(fastest)} → cumpara cel ieftin daca diferenta de viteza e acceptabila ({cheapest_buy['wall_time_sec']:.1f}s vs {fastest['wall_time_sec']:.1f}s)")

    if skipped:
        names = ", ".join(set(r["detected_gpu"] for r in skipped))
        md.append(f"- **Nu poate rula:** {names}")
    md.append("")
md.append("")

# ============================================================
# SECTIUNE NOUA: Analiza CALITATIVA raspunsuri per model
# Side-by-side: hash, schema fields, action, confidence, snippet
# ============================================================
md.append("## Analiza calitativa raspunsuri (side-by-side per model)")
md.append("")
md.append("Compara CONTINUTUL raspunsurilor intre GPU-uri. Cu `temperature=0` + `seed=42` raspunsurile ar trebui sa fie identice (sau foarte similare). Diferentele indica:")
md.append("- nondeterminism numeric (FP16 vs FP32, KV cache q8_0 vs f16)")
md.append("- model degradat de truncare prompt (ar trebui sa nu se mai intample cu ctx adaptiv)")
md.append("- bug intr-un anumit GPU/driver")
md.append("")
md.append("**Schema fields verificate:** " + ", ".join(f"`{f}`" for f in EXPECTED_TOP_LEVEL_FIELDS))
md.append("")

for model_base in sorted(by_model.keys(), key=lambda k: model_size_key(by_model[k])):
    model_rows = [r for r in by_model[model_base] if r["status"] == "OK"]
    if not model_rows:
        continue

    md.append(f"### `{model_base}`")
    md.append("")

    # Tabel sumar calitativ
    md.append("| GPU (real) | JSON | Schema | Action | Confidence | Resp len | Fingerprint | Wall (s) |")
    md.append("|---|:---:|:---:|:---:|---:|---:|:---:|---:|")
    sorted_rows = sorted(model_rows, key=lambda r: r["wall_time_sec"])
    fingerprints_seen = {}
    for r in sorted_rows:
        gpu_label = r["detected_gpu"] or r["target_gpu"]
        if r["proxy_mode"]:
            gpu_label += " *(proxy)*"
        is_json = "✓" if r["response_is_valid_json"] else "✗"
        schema_str = f"{r['_schema_present']}/{r['_schema_total']}"
        action = str(r["_action"]) if r["_action"] is not None else "-"
        conf = f"{r['_confidence']:.2f}" if isinstance(r["_confidence"], (int, float)) else (str(r["_confidence"])[:10] if r["_confidence"] is not None else "-")
        fp = r["_fingerprint"]
        # Marcheaza primul aparition vs duplicate
        if fp not in fingerprints_seen:
            fingerprints_seen[fp] = gpu_label
            fp_disp = f"`{fp}` (1st)"
        else:
            same_as = fingerprints_seen[fp]
            fp_disp = f"`{fp}` = {same_as}"
        md.append(f"| {gpu_label} | {is_json} | {schema_str} | {action} | {conf} | {r['response_chars']} | {fp_disp} | {r['wall_time_sec']:.1f} |")
    md.append("")

    # Snippet-uri pentru fingerprint-uri DISTINCTE
    distinct_fps = {}
    for r in sorted_rows:
        fp = r["_fingerprint"]
        if fp not in distinct_fps:
            distinct_fps[fp] = r
    if len(distinct_fps) > 1:
        md.append(f"**Variante distincte de raspuns: {len(distinct_fps)}** (vezi snippet-urile mai jos)")
        md.append("")
    else:
        md.append(f"**Toate GPU-urile au dat raspuns IDENTIC** ({list(distinct_fps.keys())[0]})")
        md.append("")

    for fp, r in distinct_fps.items():
        gpu_label = r["detected_gpu"] or r["target_gpu"]
        md.append(f"<details><summary>Snippet `{fp}` (primul de pe `{gpu_label}`, len={r['response_chars']} chars)</summary>")
        md.append("")
        md.append("```json")
        md.append(response_snippet(r["response_text"], 800))
        md.append("```")
        # Schema breakdown
        if r["_schema_missing_list"]:
            md.append(f"_Lipseste din schema:_ {', '.join('`'+x+'`' for x in r['_schema_missing_list'])}")
        md.append("</details>")
        md.append("")
    md.append("")

# ============================================================
# Tabel mare global, sortat dupa wall-time
# ============================================================
md.append("## Tabel comparativ GLOBAL (toate runs OK, sortate dupa wall-time)")
md.append("")
md.append("| GPU (real) | Model | ctx used | Prompt tok | Wall (s) | Eval tok/s | VRAM peak | JSON |")
md.append("|---|---|---:|---:|---:|---:|---:|:---:|")

for r in ok_rows:
    proxy_mark = " *(proxy)*" if r["proxy_mode"] else ""
    is_json_v = r["response_is_valid_json"]
    is_json = "✓" if is_json_v is True else ("✗" if is_json_v is False else "-")
    md.append(f"| {r['detected_gpu']}{proxy_mark} | `{r['model']}` | "
              f"{r['ctx_used']} | {r['prompt_tokens_real']} | "
              f"{r['wall_time_sec']:.1f} | {r['eval_rate']:.1f} | "
              f"{r['vram_peak_mb']} | {is_json} |")

if fail_rows:
    md.append("")
    md.append("### Failures (PROMPT_TOO_LARGE / OOM / TIMEOUT / FAILED)")
    md.append("")
    md.append("| GPU | Model | Status | ctx max | ctx needed | Note |")
    md.append("|---|---|:---:|---:|---:|---|")
    for r in fail_rows:
        ctx_max = r.get("ctx_max_fits", 0)
        ctx_used = r.get("ctx_used", 0)
        note = ""
        if r["status"] == "PROMPT_TOO_LARGE":
            note = "Cardul nu poate procesa prompt-ul curent cu acest model"
        md.append(f"| {r['detected_gpu']} | `{r['model']}` | {r['status']} | {ctx_max} | {ctx_used} | {note} |")
md.append("")

# ============================================================
# CHEAPEST VIABLE GPU PER MODEL (use case driven recomandare)
# ============================================================
md.append("## Cea mai ieftina placa care ruleaza CORECT fiecare model")
md.append("")
md.append("Pentru fiecare LLM, gasim cardul cu **cel mai mic pret de cumparare** care:")
md.append("- A rulat modelul cu success (status=OK)")
md.append("- A returnat JSON valid")
md.append("- A acoperit >=50% din schema asteptata")
md.append("")
md.append("Asa decizi: 'daca minim necesar e modelul X, pot lua cardul Y la pretul Z'.")
md.append("")
md.append("| Model | Cea mai ieftina placa CORECTA | Pret | Wall (s) | Schema | Vs cea mai rapida |")
md.append("|---|---|---:|---:|:---:|---|")

for model_base in sorted(by_model.keys(), key=lambda k: model_size_key(by_model[k])):
    model_rows = [r for r in by_model[model_base] if r["status"] == "OK"]
    valid = [r for r in model_rows
             if r["response_is_valid_json"] and r["_schema_present"] >= r["_schema_total"] // 2]
    if not valid:
        # macar JSON valid
        valid = [r for r in model_rows if r["response_is_valid_json"]]
    if not valid:
        md.append(f"| `{model_base}` | (niciun GPU n-a dat raspuns valid) | - | - | - | - |")
        continue
    cheapest = min(valid, key=lambda r: r["purchase_price_usd"])
    fastest = min(valid, key=lambda r: r["wall_time_sec"])
    cmp_str = ""
    if cheapest["gpu_key"] != fastest["gpu_key"]:
        diff_s = cheapest["wall_time_sec"] - fastest["wall_time_sec"]
        diff_pct = (diff_s / fastest["wall_time_sec"] * 100) if fastest["wall_time_sec"] > 0 else 0
        savings = fastest["purchase_price_usd"] - cheapest["purchase_price_usd"]
        cmp_str = f"+{diff_s:.1f}s ({diff_pct:+.0f}%) mai lent decat {fastest['detected_gpu']} dar economisesti ${savings:.0f}"
    else:
        cmp_str = "este si cea mai rapida"
    label = cheapest["detected_gpu"]
    if cheapest["proxy_mode"]:
        label += f" *(proxy pt {cheapest['target_gpu']})*"
    md.append(f"| `{model_base}` | {label} | ${cheapest['purchase_price_usd']:.0f} | "
              f"{cheapest['wall_time_sec']:.1f} | "
              f"{cheapest['_schema_present']}/{cheapest['_schema_total']} | {cmp_str} |")
md.append("")

# Recomandare strategica: minimum VRAM per model coerent
md.append("### Decizie strategica: ce VRAM minim ai nevoie?")
md.append("")
vram_by_model = {}
for model_base in by_model:
    valid = [r for r in by_model[model_base]
             if r["status"] == "OK" and r["response_is_valid_json"]
             and r["_schema_present"] >= r["_schema_total"] // 2]
    if valid:
        min_vram = min(r["detected_vram_total_mb"] for r in valid)
        vram_by_model[model_base] = min_vram

if vram_by_model:
    for model_base, min_vram_mb in sorted(vram_by_model.items(), key=lambda kv: kv[1]):
        vram_gb = (min_vram_mb + 512) // 1024
        md.append(f"- `{model_base}` -> VRAM minim necesar: **{vram_gb} GB** (verificat empiric)")
    md.append("")
    md.append("**Implicatie:** alege VRAM-ul cardului in functie de cel mai mare model pe care vrei sa-l rulezi local. Modelele care nu apar deloc in lista de mai sus n-au putut fi validate pe niciun card -> fie cresti VRAM, fie reduci prompt-ul, fie schimbi modelul.")
else:
    md.append("- (nu exista date suficiente)")
md.append("")

# Recomandare automata
md.append("## Recomandare automata")
md.append("")
candidates = []
for s in summaries:
    best = best_model_for_gpu(s)
    if not best:
        continue
    purchase = s["purchase_price_usd"]
    candidates.append({
        "gpu": s["target_gpu"],
        "model": best["model"],
        "wall_time": best["wall_time_sec"],
        "purchase": purchase,
        "proxy_mode": s["proxy_mode"],
        "valid_json": best.get("response_is_valid_json"),
    })

if candidates:
    # Best by speed (wall time)
    fastest = min(candidates, key=lambda c: c["wall_time"])
    md.append(f"- **Cel mai RAPID**: {fastest['gpu']} cu `{fastest['model']}` in **{fastest['wall_time']:.1f}s/analiza**"
              + (" (proxy)" if fastest["proxy_mode"] else ""))

    # Cheapest to buy
    cheapest_buy = min(candidates, key=lambda c: c["purchase"])
    md.append(f"- **Cel mai ieftin de cumparat**: {cheapest_buy['gpu']} - **${cheapest_buy['purchase']:.0f}** ({cheapest_buy['wall_time']:.1f}s cu `{cheapest_buy['model']}`)"
              + (" (proxy)" if cheapest_buy["proxy_mode"] else ""))

    # Best value: din placile cu raspuns valid, cea mai ieftina
    valid_cands = [c for c in candidates if c["valid_json"]]
    if valid_cands:
        best_value = min(valid_cands, key=lambda c: c["purchase"])
        if best_value["gpu"] != cheapest_buy["gpu"]:
            md.append(f"- **Best value (raspuns valid + cel mai ieftin)**: {best_value['gpu']} - **${best_value['purchase']:.0f}** ({best_value['wall_time']:.1f}s)")

    md.append("")
    md.append("**Atentie pentru rezultatele cu *(proxy)***: GPU-ul real va fi de obicei mai rapid decat surogatul.")
md.append("")

# ---------------------------------------------------------------------------
# Notes about proxy mode
# ---------------------------------------------------------------------------
proxy_summaries = [s for s in summaries if s["proxy_mode"]]
if proxy_summaries:
    md.append("## ⚠ Note proxy mode")
    md.append("")
    md.append("Urmatoarele rezultate au fost obtinute pe GPU surogat (target nu e disponibil pe Vast.ai):")
    md.append("")
    for s in proxy_summaries:
        md.append(f"- **{s['target_gpu']}**: rulat pe `{s['detected_gpu']}` - rezultatele sunt **lower bound**")
    md.append("")

with open("FINAL-REPORT.md", "w") as f:
    f.write("\n".join(md) + "\n")
print(f"[OK] FINAL-REPORT.md scris ({len(md)} linii)")

# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------
final_json = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "exchange_rate_ron_usd": EXCHANGE_RATE,
    "gpus_tested": len(summaries),
    "total_runs": len(rows),
    "summaries": summaries,
    "rows_sorted_by_wall_time": ok_rows,
    "recommendations": candidates if candidates else [],
}
with open("FINAL-REPORT.json", "w") as f:
    json.dump(final_json, f, indent=2)
print(f"[OK] FINAL-REPORT.json scris")

# Console summary
print()
print("=" * 60)
print(" FINAL REPORT")
print("=" * 60)
for c in sorted(candidates, key=lambda x: x["wall_time"]):
    proxy = " (proxy)" if c["proxy_mode"] else ""
    valid = "JSON ✓" if c["valid_json"] else "JSON ✗"
    print(f"  {c['gpu']:30s}{proxy:10s}  best={c['model']:18s}  "
          f"{c['wall_time']:6.1f}s/run  ${c['purchase']:>5.0f} buy  {valid}")
print()
print("Vezi FINAL-REPORT.md pentru detalii complete.")
PYEOF
