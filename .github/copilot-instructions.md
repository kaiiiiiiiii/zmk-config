# AI Agent Instructions for zmk-config

Concise, project-specific guidance to be productive quickly## 8. When Modifying
/ Adding Recipes

- Reuse helper functions (`_parse_targets`, `_build_single`).
- Keep new scripts using same safety flags & artifact patterns.
- If introducing new per-target metadata for draw, mirror existing associative
  array approach.
- Use absolute paths for directories to ensure consistency.
- Follow bash best practices: `set -euo pipefail` for error handling.
- For new build targets, update `build.yaml` with board, shield, optional
  snippet, optional artifact-name.
- For new draw targets, add entries to `LAYOUTS` and `KEYBOARDS` associative
  arrays in the `draw` recipe.
- Test new recipes with `just <recipe>` before committing.p responses focused on
  THIS repo's workflows & conventions.

## 0. Project Description

This repository contains a personal ZMK (Zephyr Mechanical Keyboard) firmware
configuration for building custom keyboard firmware. It supports multiple
keyboards (e.g., Cheapino v2, Ergonaut One) with cross-platform OS switching
(Windows/macOS), home row modifiers, optimized navigation, and visual keymap
diagrams. The setup uses Nix for reproducible development environments, direnv
for automatic activation, and Just for task automation. Key features include
declarative build matrices, automated keymap drawing, and testing workflows.

## 1. Purpose & Structure

This repository is a personal ZMK (Zephyr Mechanical Keyboard) configuration.
Core intent:

- Define firmware builds for multiple boards/shields via `build.yaml`.
- Maintain keymaps (`config/*.keymap`) and shield definitions
  (`config/boards/shields/**`).
- Provide reproducible, isolated dev environment (Nix + direnv) and workflow
  automation (`Justfile`).
- Generate visual keymap diagrams with keymap-drawer (`just draw`).

Key dirs/files:

- `build.yaml` – Declarative build matrix (board, shield, optional snippet,
  optional artifact-name).
- `config/` – All ZMK config: `west.yml`, global _.conf, _.keymap, combo/leader
  DTS includes, shield folders.
- `config/boards/shields/<shield>/` – Shield-specific Kconfig, DTS overlays,
  keymap, layout `.dtsi`, ZMK metadata `.zmk.yml`.
- `Justfile` – Canonical task runner: build, draw, init, list, test, clean.
- `keymap-drawer/` – Output (YAML + SVG) from `just draw`; includes
  `config.yaml` for rendering settings.
- `flake.nix` / `flake.lock` – Nix provisioning for toolchain (west, Zephyr SDK,
  python deps, keymap-drawer, yq, etc.).

## 2. Build Workflow

Primary command interface is `just` (never hardcode raw west unless necessary):

- `just init` – Initialize Zephyr workspace (west init + update + export).
- `just list` – Show all build target tuples derived from `build.yaml`.
- `just build <expr>` – Filter targets (case-insensitive substring match; `all`
  expands). Pass extra west args after expression, e.g. `just build all -p` for
  pristine.
- Internals: `_parse_targets` (yq + combinations) → lines of
  `board,shield,snippet,artifact`. `_build_single` invokes `west build` with
  `-DZMK_CONFIG=config` and optional `-DSHIELD` / snippet (`-S`). Output
  artifact copied to `firmware/` as `.uf2` if present else `.bin`.
- Clean: `just clean` (build + firmware) / `just clean-all` (also .west + zmk
  modules) / `just clean-nix` (GC nix store).

## 3. Drawing Keymaps

- `just draw [targets...]` – Variadic. No args or `all` → all known targets.
- Metadata maps inside recipe: `LAYOUTS[name]`, `KEYBOARDS[name]` provide `-l`
  and `-k` for keymap-drawer.
- Pipeline per target: parse (`keymap parse -z ... --virtual-layers Combos`) →
  post-process combos layer via `yq` (best-effort) → render (`keymap draw`).
  Produces `<name>.yaml` + `<name>.svg` in `keymap-drawer/`.
- Add target: create `config/<name>.keymap`, extend arrays in `Justfile`.

## 4. Testing Flow

- `just test <relative/path/to/test-config-dir> [--no-build] [--verbose] [--auto-accept]`.
- Builds native_posix_64 with assertions unless `--no-build` present.
- Runs produced `zmk.exe`, normalizes output, filters through `events.patterns`,
  diffs against `keycode_events.snapshot` (golden). `--auto-accept` updates
  snapshot.
- Place test assets (patterns, snapshot) in the specified directory (mirrors ZMK
  event testing style).

## 5. Conventions & Patterns

- Keymap naming: `<target>.keymap` at repo root `config/` for draw;
  shield-specific variants live under shield folders (left/right) for firmware
  builds.
- Firmware artifact naming: `${shield// /+}-${board}` unless overridden by
  `artifact-name` in `build.yaml`.
- Use yq (v4) for YAML, prefer in-place `-Yi` edits.
- Fail fast in scripts: `set -euo pipefail` used consistently.
- Virtual Combos layer labeled "Combos"; draw recipe tolerates absence of combos
  (stderr suppressed for yq edit).

## 6. External Dependencies

Provisioned by Nix (do NOT add ad-hoc install steps): west, Zephyr SDK,
keymap-drawer CLI (`keymap`), `yq`, toolchain for cross-compilation. Rely on
environment activation via direnv; commands assume it's active.

## 7. Common Tasks (Examples)

- Build everything pristine: `just build all -p`.
- Build only cheapinov2 targets: `just build cheapinov2`.
- Draw both keymaps: `just draw` (implicit all) or
  `just draw cheapinov2 ergonaut_one`.
- Add new board+shield: extend `build.yaml`, then `just build <substring>`.
- Update dependencies: `just update` (west), `just upgrade-sdk` (flake inputs &
  Python deps).

## 8. When Modifying / Adding Recipes

- Reuse helper functions (`_parse_targets`, `_build_single`).
- Keep new scripts using same safety flags & artifact patterns.
- If introducing new per-target metadata for draw, mirror existing associative
  array approach.

## 9. Non-Goals / Avoid

- Don't embed secret material; repo is config only.
- Don't bypass `Justfile` with bespoke shell in docs; keep workflows
  centralized.
- No speculative refactors to upstream ZMK modules here; this repo configures
  them.

## 10. PR Guidance (for agents)

- Minimal, focused diffs; preserve established style.
- Update README if user-facing workflow changes (esp. `Justfile` recipes or
  build matrix behavior).
- Run a representative build (`just build <one target>`) or test
  (`just test ...`) after altering config logic.

Feedback welcome: clarify anything unclear before large changes.
