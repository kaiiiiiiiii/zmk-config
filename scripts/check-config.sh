#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    echo "Configuration check failed: $*" >&2
    exit 1
}

targets="$(just _parse_targets all)"
[[ -n "$targets" ]] || fail "build.yaml produced no targets"

duplicate_artifacts="$(printf '%s\n' "$targets" | awk -F, '{print $4}' | sort | uniq -d)"
[[ -z "$duplicate_artifacts" ]] || fail "duplicate artifact names: $duplicate_artifacts"

printf '%s\n' "$targets" | grep -Fq 'rp2040_zero,cheapinov2,studio-rpc-usb-uart,cheapinov2-rp2040_zero' ||
    fail "Cheapino must target the RP2040-Zero"

for half in adv360pro_left adv360pro_right; do
    printf '%s\n' "$targets" | grep -Fq "$half//zmk,settings_reset,,settings_reset-$half" ||
        fail "missing settings-reset target for $half"
done

for central in adv360pro_left ergonaut_one_left; do
    conf="config/$central.conf"
    grep -Fxq 'CONFIG_BT_MAX_CONN=4' "$conf" || fail "$conf must reserve four connections"
    grep -Fxq 'CONFIG_BT_MAX_PAIRED=4' "$conf" || fail "$conf must reserve four bonds"
done

if grep -Eq 'cheapino-zmk-config-single-nicenano|self-hosted' \
    config/west.yml .github/workflows/build.yml; then
    fail "obsolete Cheapino module or unsafe workflow setting remains"
fi

grep -Fq 'if SHIELD_CHEAPINOV2' hardware/cheapino/boards/shields/cheapinov2/Kconfig.defconfig ||
    fail "Cheapino Kconfig defaults must be shield-scoped"
grep -Fq 'kscan = <&cheapino_filtered_scan>;' \
    hardware/cheapino/boards/shields/cheapinov2/cheapinov2.dtsi ||
    fail "Cheapino encoder/keymap input must pass through the v2 ghost filter"

grep -Fq '&hmr RGUI K' config/base.keymap || fail "macOS right-hand GUI modifier regression"
grep -Fq '&hmr RCTRL SEMI' config/base.keymap || fail "macOS right-hand Control modifier regression"
grep -Fq 'MAC_BSPC_MORPH  &mt LA(BSPC)' config/base.keymap ||
    fail "macOS previous-word deletion must use Option"

echo "Configuration checks passed."
