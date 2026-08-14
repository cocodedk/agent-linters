# Concise linter output for every tool and every agent. Source from
# ~/.config/fish/config.fish, OUTSIDE any `if status is-interactive` block — agents run
# fish non-interactively:
#
#   test -f $HOME/projects/agent-linters/shell/linters.fish
#       and source $HOME/projects/agent-linters/shell/linters.fish

# See shell/linters.sh for why each of these exists.
set -gx RUFF_OUTPUT_FORMAT concise

if set -q XDG_CACHE_HOME
    set -gx RUFF_CACHE_DIR $XDG_CACHE_HOME/ruff
else
    set -gx RUFF_CACHE_DIR $HOME/.cache/ruff
end

# fish_add_path prepends and is idempotent. ~/.local/bin holds lintp; the shims must land
# ahead of the real binaries, so add them last.
fish_add_path -g $HOME/.local/bin
fish_add_path -g $HOME/.local/shims
