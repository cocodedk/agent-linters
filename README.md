# agent-linters

Linter output rewritten as short, imperative prompts, so a coding agent gets an
instruction instead of a screenful of diagnostics.

```
$ lintp src/
src/api.py:1     remove unused import `os`
src/api.py:14    return str, not int
src/ui.tsx:8     add a `key` prop to the list element
src/theme.css:1  remove the duplicate CSS property

4 findings, 2 auto-fixable (lintp --fix)
```

Ruff's default output for those first two findings alone is fourteen lines of code
frames and help text. That is fine for a human reading one error, and wasteful for an
agent that has to hold a whole codebase in context.

Everything here works at the tool layer — environment variables, user-level config and
two PATH shims — so it applies to any agent that shells out to a linter (Claude Code,
Codex, and anything else) without configuring each one separately.

## Install

The linters themselves are not bundled:

```sh
uv tool install ruff && uv tool install mypy      # Python
npm install -g oxlint @biomejs/biome              # JS/TS, CSS/JSON
```

Then:

```sh
git clone https://github.com/cocodedk/agent-linters ~/projects/agent-linters
cd ~/projects/agent-linters && ./install.sh
```

It symlinks `bin/`, `shims/` and `config/` into `~/.local` and `~/.config`, and adds one
`source` line to `~/.profile` and `~/.config/fish/config.fish`. Any real file already at a
target is moved to `<name>.bak` first. Re-running is safe; `./install.sh --uninstall`
reverses it, restoring backups.

Claude Code reads its own `env` block rather than your shell profile, so also add:

```json
"env": {
  "RUFF_OUTPUT_FORMAT": "concise",
  "RUFF_CACHE_DIR": "/home/YOU/.cache/ruff"
}
```

to `~/.claude/settings.json` — or run `./install.sh --claude` to have `jq` do it.

## lintp

Routes by file type and prints one line per finding:

| Extensions | Linter |
|---|---|
| `.py .pyi` | ruff + mypy |
| `.js .mjs .cjs .jsx .ts .tsx .mts .cts` | oxlint |
| `.css .scss .json .jsonc` | biome |

biome also lints JS/TS, so those findings are dropped — oxlint owns them, and duplicate
prompts are worse than none.

| Flag | Effect |
|---|---|
| `--fix` | apply the safe autofixes first, then report what remains |
| `--codes` | append the rule name to each line |
| `--strict` | add oxlint's `pedantic` and `style` rules |
| `--tools ruff,mypy,oxlint,biome` | run a subset |

Exit codes: `0` clean, `1` findings, `2` a linter failed to run.

Roughly fifty rules have a hand-written phrasing (`F401` → "remove unused import `os`",
`jsx-key` → "add a `key` prop to the list element", `return-value` → "return str, not
int"). Unmapped biome rules are turned into an instruction from the rule name
(`noDescendingSpecificity` → "avoid descending specificity"), which reads better than
biome's explanatory sentence. Anything still unmapped falls through to the linter's own
message, so **nothing is ever swallowed**.

A project's own config always wins. Where a repo has an `.oxlintrc.json`, lintp passes it
with `-c` and adds no category flags of its own.

## What the shims are for

Both keep output to one line per finding where no environment variable can. Each `exec`s
the real binary, so exit codes pass through untouched, and each finds it by walking `PATH`
and skipping its own directory.

- **`shims/mypy`** — mypy has no env var for output flags, and a project `mypy.ini` or
  `pyproject.toml` replaces a user-level config wholesale, so only a command-line flag
  reaches every invocation. `mypy --error-summary` still restores the summary. It also
  gives each working directory its own cache, outside the project (see below).
- **`shims/biome`** — biome's `concise` reporter is CLI-only. Injected for `lint`, `check`
  and `ci`; `format` and the rest are untouched, and passing your own `--reporter` makes
  the shim step aside.

## Traps worth knowing

Each of these cost real debugging, and each one made a linter point at the wrong thing.

**Never set one shared `MYPY_CACHE_DIR`.** Two projects that each contain a module of the
same name — `utils.py`, `main.py`, `conftest.py` — collide in a shared cache, and mypy then
reports the finding against *the other project's file*. An agent that trusts the path edits
a file in the wrong repository. The shim gives each directory its own cache instead. Note
that an inherited `MYPY_CACHE_DIR` wins over the shim, as an explicit setting should — so if
you ever exported a shared one, unset it.

**ruff lints whatever file you name, extension be damned.** `ruff check app.js` returns a
screenful of imaginary Python syntax errors. Filter paths by extension before invoking any
linter; `lintp` does this in `select()`.

**mypy prints paths relative to the target it was given, not to the cwd.** A bare `a.py` in
its output can silently resolve to a different same-named file in the current directory.
Anchor reported paths to the target roots first; `lintp` does this in `resolve()`.

**oxlint reads its config from the cwd only**, while ruff, mypy and biome all search
upward. Run bare `oxlint` from the repo root, or a subdirectory run silently loses every
exception the repo's config exists to declare. `lintp` walks up and passes `-c` itself.

**A `-D <category>` on oxlint's command line outranks the project's `.oxlintrc.json`.** Any
wrapper that forces categories will switch rules back on that a repo deliberately disabled.

**oxlint prefixes `No files found to lint.` to its JSON output**, so JSON must be extracted
from the first `{` rather than parsed from the whole of stdout.

## Generic advice is sometimes wrong for a repo

Before fixing anything a linter reports in an unfamiliar codebase, tune the config until
the findings that remain are all real. Otherwise an agent "fixing" them breaks working
code. Real examples from one repository, a Samsung Tizen TV app:

- `no-array-sort` advises `Array#toSorted()` — ES2023, absent from the TV's Chromium 76.
- `no-unused-vars` called 21 cross-file globals dead, because the app loads its scripts as
  classic `<script>` tags sharing one namespace. Acting on it deletes the app.
- ruff's `I001` wanted imports sorted, which moves `from gi.repository import ...` above
  the `gi.require_version()` call that must precede it, breaking the script at import time.
- `SIM115` wanted a `with` block for the `open()` holding an `flock` — closing the file
  releases the lock and lets a second instance start.

Tuning that repo took 124 findings to 21, every survivor genuine.

## Requirements

POSIX `sh`, Python 3.8+, and the linters you want. Linux and macOS; the mypy shim prefers
`md5sum`, falls back to `md5` then `cksum`, and degrades to mypy's default project-local
cache if none is present.

## Licence

MIT — see [LICENSE](LICENSE).
