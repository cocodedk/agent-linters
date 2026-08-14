#!/bin/sh
# Install the linter tooling by symlinking it into place. Idempotent: safe to re-run
# after a git pull. Any real file already at a target is moved aside to <name>.bak
# before being replaced, and profile lines are only ever added once.
#
#   ./install.sh            symlink everything, hook both shell profiles
#   ./install.sh --claude   also patch ~/.claude/settings.json's env block (needs jq)
#   ./install.sh --uninstall  remove the symlinks and the profile lines
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
bin_dir="$HOME/.local/bin"
shim_dir="$HOME/.local/shims"
profile="$HOME/.profile"
fish_config="$config_home/fish/config.fish"
sh_line="[ -f \"$repo/shell/linters.sh\" ] && . \"$repo/shell/linters.sh\""
fish_line="test -f $repo/shell/linters.fish; and source $repo/shell/linters.fish"

do_claude=no
do_uninstall=no
for arg in "$@"; do
    case "$arg" in
        --claude) do_claude=yes ;;
        --uninstall) do_uninstall=yes ;;
        *) echo "install.sh: unknown option $arg" >&2; exit 2 ;;
    esac
done

link() {  # link <source-in-repo> <target>
    src="$repo/$1"
    dst="$2"
    mkdir -p "$(dirname -- "$dst")"
    if [ -L "$dst" ]; then
        [ "$(readlink -- "$dst")" = "$src" ] && { echo "  ok       $dst"; return; }
        rm -f -- "$dst"
    elif [ -e "$dst" ]; then
        mv -- "$dst" "$dst.bak"
        echo "  backup   $dst -> $dst.bak"
    fi
    ln -s -- "$src" "$dst"
    echo "  link     $dst"
}

unlink_ours() {  # unlink_ours <source-in-repo> <target>
    dst="$2"
    if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$repo/$1" ]; then
        rm -f -- "$dst"
        echo "  removed  $dst"
        # No `&&` chain as the last statement: it returns 1 when there is no backup,
        # which under `set -e` would abort the whole uninstall right here.
        if [ -e "$dst.bak" ]; then
            mv -- "$dst.bak" "$dst"
            echo "  restored $dst from .bak"
        fi
    fi
    return 0
}

hook() {  # hook <file> <line>
    file="$1"
    line="$2"
    mkdir -p "$(dirname -- "$file")"
    [ -e "$file" ] || : > "$file"
    if grep -Fqs -- "$repo/shell/linters" "$file"; then
        echo "  ok       $file already sources the fragment"
        return
    fi
    printf '\n# agent-linters: concise linter output for every agent\n%s\n' "$line" >> "$file"
    echo "  hooked   $file"
}

unhook() {  # unhook <file>
    file="$1"
    [ -e "$file" ] || return 0
    grep -Fqs -- "$repo/shell/linters" "$file" || return 0
    tmp="$file.agent-linters.tmp"
    grep -Fv -- "$repo/shell/linters" "$file" \
        | grep -Fv -- '# agent-linters: concise linter output for every agent' > "$tmp"
    mv -- "$tmp" "$file"
    echo "  unhooked $file"
}

if [ "$do_uninstall" = yes ]; then
    echo "Uninstalling from $HOME"
    unlink_ours bin/lintp "$bin_dir/lintp"
    unlink_ours shims/mypy "$shim_dir/mypy"
    unlink_ours shims/biome "$shim_dir/biome"
    unlink_ours config/ruff/ruff.toml "$config_home/ruff/ruff.toml"
    unlink_ours config/mypy/config "$config_home/mypy/config"
    unhook "$profile"
    unhook "$fish_config"
    echo
    echo "Left alone: ~/.claude/settings.json (remove RUFF_* from its env block by hand)."
    exit 0
fi

echo "Installing from $repo into $HOME"
link bin/lintp "$bin_dir/lintp"
chmod +x "$repo/bin/lintp" "$repo/shims/mypy" "$repo/shims/biome"
link shims/mypy "$shim_dir/mypy"
link shims/biome "$shim_dir/biome"
link config/ruff/ruff.toml "$config_home/ruff/ruff.toml"
link config/mypy/config "$config_home/mypy/config"
hook "$profile" "$sh_line"
hook "$fish_config" "$fish_line"

settings="$HOME/.claude/settings.json"
if [ "$do_claude" = yes ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "  skip     --claude needs jq" >&2
    elif [ ! -f "$settings" ]; then
        echo "  skip     no $settings" >&2
    else
        cp -- "$settings" "$settings.bak"
        tmp="$settings.agent-linters.tmp"
        jq --arg cache "${XDG_CACHE_HOME:-$HOME/.cache}/ruff" \
           '.env = ((.env // {}) + {RUFF_OUTPUT_FORMAT: "concise", RUFF_CACHE_DIR: $cache})' \
           "$settings" > "$tmp" && mv -- "$tmp" "$settings"
        echo "  patched  $settings (backup at $settings.bak)"
    fi
fi

cat <<'NOTE'

Done. Open a new login shell, or run:  . ~/.profile

Claude Code reads its own env block rather than your shell profile, so unless you
passed --claude, add this to ~/.claude/settings.json yourself:

  "env": {
    "RUFF_OUTPUT_FORMAT": "concise",
    "RUFF_CACHE_DIR": "/home/YOU/.cache/ruff"
  }

The linters themselves are not installed by this script:

  uv tool install ruff && uv tool install mypy
  npm install -g oxlint @biomejs/biome
NOTE
