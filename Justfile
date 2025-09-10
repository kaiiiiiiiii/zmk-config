default:
    @just --list --unsorted

config := absolute_path('config')
build := absolute_path('.build')
out := absolute_path('firmware')
draw := absolute_path('keymap-drawer')

# parse build.yaml and filter targets by expression
_parse_targets $expr:
    #!/usr/bin/env bash
    attrs="[.board, .shield, .snippet, .\"artifact-name\"]"
    filter="(($attrs | map(. // [.]) | combinations), ((.include // {})[] | $attrs)) | join(\",\")"
    echo "$(yq -r "$filter" build.yaml | grep -v "^," | grep -i "${expr/#all/.*}")"

# build firmware for single board & shield combination
_build_single $board $shield $snippet $artifact *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${artifact:-${shield:+${shield// /+}-}${board}}"
    build_dir="{{ build / '$artifact' }}"

    echo "Building firmware for $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} ${snippet:+-S "$snippet"} -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"}

    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# build firmware for matching targets
build expr *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet artifact; do
        just _build_single "$board" "$shield" "$snippet" "$artifact" {{ west_args }}
    done

# clear build cache and artifacts
clean:
    rm -rf {{ build }} {{ out }}

# clear all automatically generated files
clean-all: clean
    rm -rf .west zmk

# clear nix cache
clean-nix:
    nix-collect-garbage --delete-old

# parse & plot keymaps
# Usage examples:
#   just draw ergonaut_one              # draw only ergonaut_one
#   just draw cheapinov2 ergonaut_one   # draw both (explicit)
#   just draw all                       # draw all known targets
#   just draw                           # draw all (implicit)
draw *targets:
    #!/usr/bin/env bash
    set -euo pipefail
    set -- {{ targets }}
    # Per-target metadata
    declare -A LAYOUTS=( \
        [cheapinov2]=LAYOUT_split_3x5_3 \
        [ergonaut_one]=LAYOUT_split_3x6_3 \
    )
    declare -A KEYBOARDS=( \
        [adv360pro]=adv360pro \
        [cheapinov2]=corne_rotated \
        [ergonaut_one]=corne_rotated \
    )
    declare -A LAYER_NAMES=( \
        [adv360pro]='"DEF" "NAV" "NUM" "SYS"' \
        [cheapinov2]='"DEF (Win)" "DEF (Mac)" "NAV (Win)" "NAV (Mac)" "NUM (Windows)" "NUM (Mac)" "SYS"' \
        [ergonaut_one]='"DEF (Win)" "DEF (Mac)" "NAV (Win)" "NAV (Mac)" "NUM (Windows)" "NUM (Mac)" "SYS"' \
    )

    list_targets() { printf '%s\n' "${!KEYBOARDS[@]}" | sort; }

    draw_one() {
        local name="$1"
        local layout="${LAYOUTS[$name]:-}"
        local keyboard="${KEYBOARDS[$name]:-}"
        local layer_names="${LAYER_NAMES[$name]:-}"
        if [[ -z "$layer_names" || -z "$keyboard" ]]; then
            echo "Unknown draw target: $name" >&2
            echo -n "Valid targets: " >&2; list_targets >&2; echo "(or 'all')" >&2
            return 1
        fi
        echo "Drawing keymap: $name (keyboard=$keyboard layout=$layout layer_names=$layer_names)"
        local keymap_file="{{ config }}/$name.keymap"
        if [[ ! -f "$keymap_file" ]]; then
            echo "Missing keymap file: $keymap_file" >&2
            return 1
        fi
        local yaml_out="{{ draw }}/$name.yaml"
        local svg_out="{{ draw }}/$name.svg"
        eval "keymap -c '{{ draw }}/config.yaml' parse -z '$keymap_file' --virtual-layers Combos --layer-names $layer_names > '$yaml_out'"
        # Attach virtual Combos layer to all combos for drawing (ignore errors if no combos)
        yq -Yi '.combos.[].l = ["Combos"]' "$yaml_out" 2>/dev/null || true
        # Build draw arguments; omit -l when layout is empty
        draw_args=()
        [[ -n "$keyboard" ]] && draw_args+=("-z" "$keyboard")
        [[ -n "$layout" ]] && draw_args+=("-l" "$layout")

        keymap -c "{{ draw }}/config.yaml" draw "$yaml_out" "${draw_args[@]}" >"$svg_out"
    }

    # If no targets supplied treat as 'all'
    if [[ $# -eq 0 ]]; then
        set -- all
    fi

    # Disallow mixing 'all' with explicit targets
    if [[ $# -gt 1 ]]; then
        for t in "$@"; do
            if [[ $t == all ]]; then
                echo "Error: 'all' cannot be combined with explicit targets." >&2
                echo "Usage:" >&2
                echo "  just draw                    # draw all" >&2
                echo "  just draw all                # draw all" >&2
                echo "  just draw TARGET [TARGET...] # draw only specified targets" >&2
                echo -n "Valid targets: " >&2; list_targets >&2
                exit 2
            fi
        done
    fi

    expanded=()
    for t in "$@"; do
        if [[ $t == all ]]; then
            while IFS= read -r name; do expanded+=("$name"); done < <(list_targets)
        else
            expanded+=("$t")
        fi
    done

    # De-duplicate while preserving order
    # Use associative array for de-dup to avoid numeric index errors under set -u
    declare -A seen=()
    out_list=()
    for t in "${expanded[@]}"; do
        [[ -n ${seen[$t]:-} ]] && continue
        seen[$t]=1
        out_list+=("$t")
    done

    for t in "${out_list[@]}"; do
        draw_one "$t"
    done

# initialize west
init:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -d .west ]; then
        echo "west already initialized; skipping init"
    else
        west init -l config
    fi
    west update --fetch-opt=--filter=blob:none
    west zephyr-export

# list build targets
list:
    @just _parse_targets all | sed 's/,*$//' | sort | column

# update west
update:
    west update --fetch-opt=--filter=blob:none

# upgrade zephyr-sdk and python dependencies
upgrade-sdk:
    nix flake update --flake .
