# AI Agent Instructions for zmk-config

Project-specific guidance for this personal ZMK firmware configuration.

## Repository layout

- `build.yaml` declares all board, shield, snippet, and artifact combinations.
- `config/` contains keymaps, per-keyboard Kconfig fragments, and `west.yml`.
- `hardware/cheapino/` is a local Zephyr/ZMK module for the stock Cheapino v2
  RP2040-Zero hardware and its matrix-connected encoder.
- `Justfile` is the canonical interface for initialization, builds, validation,
  drawing, updates, and cleanup.
- `keymap-drawer/` contains rendering configuration and generated YAML/SVG.
- `flake.nix` and `nix/` provide the toolchain and Python packages.

## Commands

- `just init`: initialize and update the West workspace.
- `just list`: list tuples derived from `build.yaml`.
- `just build <literal-substring> [west args]`: build matching targets; `all`
  selects every target. Use `-p` for pristine builds.
- `just draw [targets...]`: draw all keymaps or the named targets.
- `just check`: run fast repository invariant checks.
- `just clean`: remove build directories and firmware artifacts.
- `just clean-all`: also remove the generated West workspace and modules.
- `just update`: update projects to revisions pinned by `config/west.yml`.
- `just upgrade-dependencies`: update all Nix flake inputs.

The Nix shell supplies West, the Zephyr SDK, Just, keymap-drawer, and Python
yq. Do not add ad-hoc dependency installation instructions.

## Build conventions

- Reuse `_parse_targets` and `_build_single` instead of invoking West directly
  from documentation or additional recipes.
- Use absolute directory paths and `set -euo pipefail` in Bash recipes/scripts.
- Firmware is copied to `firmware/` as UF2 when available, otherwise BIN.
- For a new target, update `build.yaml` and use an explicit artifact name.
- Split central Bluetooth capacity must reserve one bond for the peripheral.
- Provide settings-reset targets for every independently flashable split half.

## Hardware conventions

- Keep reusable/out-of-tree hardware in a proper Zephyr module, not under the
  deprecated `config/boards` or `config/dts` paths.
- Scope every shield Kconfig default with its `SHIELD_*` condition.
- The Cheapino target is the stock v2 design: one RP2040-Zero and an RJ45 matrix
  cable. Do not reintroduce the single-Nice-Nano proof-of-concept module.
- Changes to the Cheapino matrix must be checked against the official v2 QMK
  pin map and must preserve encoder sideband coordinates.

## Drawing conventions

- Add target metadata to the `LAYOUTS`, `KEYBOARDS`, and `LAYER_NAMES`
  associative arrays in the `draw` recipe.
- Keep layer names pipe-delimited so the recipe can form an argument array
  without `eval`.
- Generated `<name>.yaml` and `<name>.svg` files are committed.

## Change validation

Run at minimum:

```bash
just check
just draw all
just build <affected-target> -p
```

For build-system, shared-keymap, or dependency changes, run
`just build all -p`. Keep diffs focused and update the README for user-visible
workflow or flashing changes.

## Safety

- Never embed credentials or runner registration tokens.
- CI for pull requests must use GitHub-hosted runners with read-only contents
  permission. Isolate any write permission in a trusted push-only job.
- Pin third-party GitHub Actions to full commit SHAs.
- Do not add project recipes that perform global Nix garbage collection.
