# Concise linter output for every tool and every agent. Source from ~/.profile:
#
#   [ -f "$HOME/projects/agent-linters/shell/linters.sh" ] && . "$HOME/projects/agent-linters/shell/linters.sh"
#
# Use ~/.profile, not ~/.bashrc: on Debian/Ubuntu, ~/.bashrc returns early for
# non-interactive shells (`case $- in *i*) ;; *) return;; esac`), and non-interactive is
# exactly how coding agents run commands.

# ruff prints a multi-line code frame plus a help block per finding by default. The env
# var is what makes this stick: it outranks a project's own [tool.ruff] output-format,
# while an explicit --output-format on the command line still wins, so JSON/SARIF
# consumers and CI are unaffected.
export RUFF_OUTPUT_FORMAT=concise

# Keep .ruff_cache/ out of every project. Safe to share across projects, unlike mypy's
# cache: ruff keys entries by absolute path, so same-named modules cannot collide.
export RUFF_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ruff"

# ~/.local/bin holds lintp. Most distros add it in ~/.profile, but not all, and a profile
# this installer had to create from scratch will not have it at all.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac

# Shims must precede the real binaries (see shims/ for why each exists).
case ":$PATH:" in
    *":$HOME/.local/shims:"*) ;;
    *) PATH="$HOME/.local/shims:$PATH" ;;
esac
export PATH
