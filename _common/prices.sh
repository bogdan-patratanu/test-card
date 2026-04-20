# =============================================================================
# prices.sh - Preturi de cumparare si tarife Vast.ai per GPU
# Modifica AICI cand gasesti deal-uri mai bune pe OLX/eMag sau cand Vast.ai
# isi schimba preturile. Tot restul codului citeste de aici.
# =============================================================================
#
# Format: PRICES_<gpu_key>__purchase si PRICES_<gpu_key>__vast_hourly
# (bash 4 nu are mape asociative-de-asociative, asa ca folosim prefix flat)
# =============================================================================

# RTX 5060 Ti 16GB - placa NOUA pe eMAG, garantie
PRICES_rtx5060ti_16gb__purchase=696
PRICES_rtx5060ti_16gb__vast_hourly=0.064
PRICES_rtx5060ti_16gb__source="eMAG nou (MSI Shadow 2X OC Plus)"

# Quadro P5000 16GB - second hand pe OLX, range 217-518 USD
# Folosim pretul mediu ~380 USD
PRICES_quadro_p5000_16gb__purchase=380
PRICES_quadro_p5000_16gb__vast_hourly=0.10  # surogat Tesla P40 24GB pe Vast
PRICES_quadro_p5000_16gb__source="OLX second-hand (range \$217-518)"

# Quadro RTX 5000 16GB - n/a recent pe OLX. Pret estimativ international ~400 USD
PRICES_quadro_rtx5000_16gb__purchase=400
PRICES_quadro_rtx5000_16gb__vast_hourly=0.08  # surogat Tesla T4 16GB pe Vast
PRICES_quadro_rtx5000_16gb__source="estimat international (n/a recent OLX)"

# RTX 3090 24GB - cel mai bun deal OLX la momentul cercetarii
PRICES_rtx3090_24gb__purchase=760
PRICES_rtx3090_24gb__vast_hourly=0.16
PRICES_rtx3090_24gb__source="OLX Bucuresti (Zotac/Asus 24GB)"

# Tesla V100 32GB - target principal cerut, OLX Snagov
PRICES_v100_32gb__purchase=860
PRICES_v100_32gb__vast_hourly=0.21
PRICES_v100_32gb__source="OLX Snagov (server card, necesita racire externa)"

# Functie helper pentru lookup
get_price() {
    local key="$1"  # ex: rtx5060ti_16gb
    local field="$2"  # purchase | vast_hourly | source
    local var_name="PRICES_${key}__${field}"
    eval echo "\${$var_name:-}"
}
