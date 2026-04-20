#!/usr/bin/env bash
# =============================================================================
# compare-results.sh - aggregator LOCAL (ruleaza pe statia ta dupa git pull)
# Citeste results/*/summary.json si emite:
#   - FINAL-REPORT.md  (tabel sortat dupa cost/analiza + recomandari)
#   - FINAL-REPORT.json (date structurate pentru orice prelucrare ulterioara)
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERR] python3 e necesar pentru compare-results.sh"
    exit 1
fi

# Source config pentru tunables (analize/zi pentru breakeven)
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
rows = []
for s in summaries:
    for m in s.get("models", []):
        rows.append({
            "gpu_key": s["gpu_key"],
            "target_gpu": s["target_gpu"],
            "detected_gpu": s["detected_gpu"],
            "proxy_mode": s["proxy_mode"],
            "purchase_price_usd": s["purchase_price_usd"],
            "vast_price_per_hour_usd": s["vast_price_per_hour_usd"],
            "model": m.get("model"),
            "model_base": m.get("model_base"),
            "status": m.get("status"),
            "wall_time_sec": m.get("wall_time_sec", 0),
            "prompt_eval_rate": m.get("prompt_eval_rate_tok_per_sec", 0),
            "eval_rate": m.get("eval_rate_tok_per_sec", 0),
            "vram_peak_mb": m.get("vram_peak_mb", 0),
            "cost_per_analysis_usd": m.get("cost_per_analysis_usd", 0),
            "response_is_valid_json": m.get("response_is_valid_json"),
        })

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
md.append("| GPU vizat | Detectat pe Vast | Proxy? | Pret cumparare | Vast $/hr | Modele OK | Cel mai bun model |")
md.append("|---|---|:---:|---:|---:|:---:|---|")
for s in summaries:
    proxy = "DA" if s["proxy_mode"] else "nu"
    n_ok = s["models_ok"]; n_total = s["models_tested"]
    best = best_model_for_gpu(s)
    best_str = f"`{best['model']}` ({best['wall_time_sec']:.1f}s)" if best else "-"
    md.append(f"| {s['target_gpu']} | `{s['detected_gpu']}` | {proxy} | ${s['purchase_price_usd']:.0f} | ${s['vast_price_per_hour_usd']:.3f} | {n_ok}/{n_total} | {best_str} |")
md.append("")

# Tabel mare per (GPU, model), sortat dupa cost/analiza
md.append("## Tabel comparativ (toate runs sortate dupa cost/analiza Vast.ai)")
md.append("")
md.append("| GPU | Model | Status | Wall (s) | Prompt eval (tok/s) | Output (tok/s) | VRAM peak (MB) | Cost/analiza ($) | JSON valid? |")
md.append("|---|---|:---:|---:|---:|---:|---:|---:|:---:|")

ok_rows = sorted([r for r in rows if r["status"] == "OK"],
                 key=lambda r: r["cost_per_analysis_usd"])
fail_rows = [r for r in rows if r["status"] != "OK"]

for r in ok_rows:
    proxy_mark = " *(proxy)*" if r["proxy_mode"] else ""
    is_json = "YES" if r["response_is_valid_json"] else "NO" if r["response_is_valid_json"] is False else "-"
    md.append(f"| {r['target_gpu']}{proxy_mark} | `{r['model']}` | OK | "
              f"{r['wall_time_sec']:.1f} | {r['prompt_eval_rate']:.1f} | "
              f"{r['eval_rate']:.1f} | {r['vram_peak_mb']} | "
              f"{r['cost_per_analysis_usd']:.6f} | {is_json} |")

if fail_rows:
    md.append("")
    md.append("### Failures")
    md.append("")
    md.append("| GPU | Model | Status |")
    md.append("|---|---|:---:|")
    for r in fail_rows:
        md.append(f"| {r['target_gpu']} | `{r['model']}` | {r['status']} |")
md.append("")

# Breakeven analysis
md.append("## Cost/analiza si breakeven (cumparare GPU vs. Vast.ai pay-as-you-go)")
md.append("")
md.append("Pentru fiecare GPU folosim **cel mai bun model OK + valid JSON** (cel mai rapid).")
md.append("Cost/analiza = (wall_time / 3600) * vast_price_per_hour_usd.")
md.append("Cost lunar Vast la N analize/zi = N * 30 * cost_per_analysis.")
md.append("Breakeven (luni) = pret_cumparare / cost_lunar_Vast.")
md.append("")
md.append("| GPU | Model best | Cost/analiza | Cost lunar Vast (50/zi) | (100/zi) | (300/zi) | (1000/zi) | Breakeven (luni) la 100/zi | la 300/zi |")
md.append("|---|---|---:|---:|---:|---:|---:|---:|---:|")

for s in summaries:
    best = best_model_for_gpu(s)
    if not best:
        md.append(f"| {s['target_gpu']} | - | - | - | - | - | - | - | - |")
        continue
    cpa = best["cost_per_analysis_usd"]
    purchase = s["purchase_price_usd"]
    proxy_mark = " *(proxy)*" if s["proxy_mode"] else ""
    
    monthly = {n: n * 30 * cpa for n in ANALYSES_PER_DAY_SCENARIOS}
    breakeven_100 = (purchase / monthly[100]) if monthly[100] > 0 else float("inf")
    breakeven_300 = (purchase / monthly[300]) if monthly[300] > 0 else float("inf")
    
    md.append(f"| {s['target_gpu']}{proxy_mark} | `{best['model']}` | "
              f"${cpa:.6f} | ${monthly[50]:.2f} | ${monthly[100]:.2f} | "
              f"${monthly[300]:.2f} | ${monthly[1000]:.2f} | "
              f"{breakeven_100:.1f} luni | {breakeven_300:.1f} luni |")
md.append("")

# Recomandare automata
md.append("## Recomandare automata")
md.append("")
candidates = []
for s in summaries:
    best = best_model_for_gpu(s)
    if not best:
        continue
    cpa = best["cost_per_analysis_usd"]
    purchase = s["purchase_price_usd"]
    monthly_300 = 300 * 30 * cpa
    breakeven_months = purchase / monthly_300 if monthly_300 > 0 else float("inf")
    candidates.append({
        "gpu": s["target_gpu"],
        "model": best["model"],
        "wall_time": best["wall_time_sec"],
        "purchase": purchase,
        "cpa": cpa,
        "breakeven_300": breakeven_months,
        "proxy_mode": s["proxy_mode"],
        "valid_json": best.get("response_is_valid_json"),
    })

if candidates:
    # Best by speed (wall time)
    fastest = min(candidates, key=lambda c: c["wall_time"])
    md.append(f"- **Cel mai RAPID**: {fastest['gpu']} cu `{fastest['model']}` in **{fastest['wall_time']:.1f}s/analiza**" 
              + (" (proxy)" if fastest["proxy_mode"] else ""))
    
    # Best by breakeven
    fastest_breakeven = min(candidates, key=lambda c: c["breakeven_300"])
    md.append(f"- **Cel mai rapid breakeven (300 analize/zi)**: {fastest_breakeven['gpu']} - se amortizeaza in **{fastest_breakeven['breakeven_300']:.1f} luni** vs Vast.ai")
    
    # Cheapest per analysis
    cheapest = min(candidates, key=lambda c: c["cpa"])
    md.append(f"- **Cel mai ieftin/analiza pe Vast.ai**: {cheapest['gpu']} - **${cheapest['cpa']:.6f}**" 
              + (" (proxy)" if cheapest["proxy_mode"] else ""))
    
    md.append("")
    md.append("### Decision matrix")
    md.append("")
    md.append("- **<50 analize/zi**: nu cumpara nimic, foloseste Vast.ai pay-as-you-go (breakeven > ani)")
    md.append("- **100 analize/zi**: cumpara doar daca breakeven < 12 luni si ai utilizare predictibila")
    md.append("- **300+ analize/zi**: cumpara GPU-ul cu cel mai rapid breakeven din tabelul de mai sus")
    md.append("- **Atentie pentru rezultatele cu *(proxy)***: GPU-ul real va fi de obicei mai rapid decat surogatul")
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
    "rows_sorted_by_cost": ok_rows,
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
for c in sorted(candidates, key=lambda x: x["breakeven_300"]):
    proxy = " (proxy)" if c["proxy_mode"] else ""
    print(f"  {c['gpu']:30s}{proxy:10s}  best={c['model']:15s}  "
          f"{c['wall_time']:6.1f}s/run  ${c['cpa']:.6f}/run  "
          f"breakeven@300/zi: {c['breakeven_300']:.1f} luni")
print()
print("Vezi FINAL-REPORT.md pentru detalii complete.")
PYEOF
