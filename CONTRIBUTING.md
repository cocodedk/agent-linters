# Contributing to agent-linters

## Local setup

1. Clone the repo and `cd` into it.
2. Install the linters `lintp` wraps — they are not bundled:
   ```sh
   uv tool install ruff && uv tool install mypy      # Python
   npm install -g oxlint @biomejs/biome              # JS/TS, CSS/JSON
   ```
3. Run `./install.sh` to symlink `bin/`, `shims/` and `config/` into `~/.local`
   and `~/.config`, and to hook both shell profiles. `./install.sh --uninstall`
   reverses it.

## Install git hooks

Commit messages here follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, …) and a `commit-msg` hook enforces the format. Run:

```sh
./scripts/install-hooks.sh
```

This points `core.hooksPath` at `.githooks` for your checkout (that setting is
per-checkout, not committed, so every fresh clone needs to run it once) and
activates `pre-commit`, `commit-msg` and `pre-push`. `pre-commit` runs
`sh -n`/`fish -n` on staged shell files and `ruff`/`mypy` on `bin/lintp` when
those tools are on `PATH`; `commit-msg` rejects a message that doesn't match
Conventional Commits. `git commit --no-verify` bypasses them by design — they
catch accidents, not deliberate bypasses.

## Build and test commands

There is no build step and no test suite — `bin/lintp` is a single stdlib-only
Python 3 script, and the shims are POSIX `sh`. Verify a change with the tools
that will actually run against it:

```sh
ruff check bin/lintp
mypy bin/lintp
shellcheck shims/mypy shims/biome install.sh
sh -n shims/mypy shims/biome install.sh
```

Then run `lintp` against a real project (or a scratch directory with a few
deliberate findings in it) and read the output — the whole point of this repo
is what a human or agent sees on the terminal, and that only shows up by
actually running it.

## Coding style

- `bin/lintp` must stay **stdlib-only** — no third-party dependencies, ever.
  It has to run on any machine an agent shells out from, with no install step
  beyond Python itself. It must pass `ruff check` and `mypy`.
- Shell code (`install.sh`, `shims/mypy`, `shims/biome`, `shell/linters.sh`)
  is POSIX `sh`, not bash. It must pass `shellcheck` and `sh -n`. Don't use
  bashisms (`[[`, arrays, `local`) even if they happen to work under `sh` on
  your system.
- Keep functions small and focused, matching the style already in `bin/lintp`
  and `install.sh` — short, commented, one job each.

## The most valuable contribution: a new rule phrasing

`bin/lintp` turns linter output into imperative instructions by looking a
rule code up in one of four tables: `RUFF_RULES`, `MYPY_RULES`, `OXLINT_RULES`,
`BIOME_RULES`. Each entry maps a rule code to a `(regex, template)` pair (or a
list of them, tried in order) that extracts the useful bits of the linter's
own message and rephrases them as an instruction — e.g. `F401` → "remove
unused import `os`", or `jsx-key` → "add a `key` prop to the list element".

Adding an entry for a rule code you hit often is the easiest way to make this
tool better for everyone. Two things worth knowing:

- **Unmapped rules degrade gracefully.** A rule with no entry falls through
  to the linter's own message (or, for biome, a phrase derived from the rule
  name), so a missing table entry never breaks anything — it just means one
  finding reads like normal linter output instead of an imperative line.
- Write the regex against the linter's actual message text, and add a case to
  your own test run confirming the template renders sensibly before and after
  your change.

## The trap this repo exists to avoid

Never suppress or "fix" a linter finding without first confirming the advice
is actually right for the code in question — several real, current findings
in the ecosystem this tool phrases are wrong for the file they point at (a
banned API that isn't available on the target runtime, a sort rule that would
break shared-namespace globals, an import reorder that breaks Python
initialization order). Rephrasing a finding as an instruction makes it more
likely to get acted on without checking, not less, so a wrong phrasing does
more damage here than it would in an ordinary linter.

The other half of that trap: never change `bin/lintp`, a shim, or a config in
a way that would make a linter report a path that doesn't exist, or attribute
a finding to the wrong file. This has happened for real from a shared mypy
cache and from oxlint's cwd-only config lookup — see the README's "Traps
worth knowing" section before touching path resolution (`resolve()`,
`select()`) or cache handling in `shims/mypy`.

## Why everything goes through a pull request

`main` is protected: a pull request is required, the `verify` check must pass, and
force-pushes and branch deletion are refused. Approvals are set to 0, so a maintainer can
self-merge.

One thing to know, because it looks like the protection is broken: `enforce_admins` is
`false`, so a repository admin's direct push to `main` **succeeds**, printing only a
`Required status check "verify" is expected.` notice on the way through. That is deliberate
— it leaves a way out of a jam without an emergency settings change — but it means the
maintainer is on the honour system. Use a branch and a PR anyway; the protection cannot
enforce it for you.

The empty commit `test: prove protection rejects a direct push` on `main` is the artefact
of discovering exactly that. Its message is wrong: the push was not rejected. It stays
because rewriting `main` to tidy history is worse than an honest stray commit.

## PR checklist

- [ ] `ruff check` and `mypy` pass on `bin/lintp`, with no new dependency added.
- [ ] `shellcheck` and `sh -n` pass on any shell file you touched.
- [ ] Ran `lintp` against real, changed findings and confirmed the output is
      still one imperative line per finding, with the correct path and line
      number.
- [ ] If you changed `install.sh`: re-ran it and confirmed it stays idempotent
      on a second run, and that `--uninstall` still reverses it cleanly.
- [ ] Commit messages follow Conventional Commits.
