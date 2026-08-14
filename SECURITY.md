# Security Policy

## What this is

`agent-linters` is a local developer tool: a Python script (`bin/lintp`), two
POSIX `sh` shims, and an install script. It makes no network calls, holds no
credentials, and runs no server. The realistic risk is not data exposure — it
is a script with write access to your `$HOME` and your `PATH` doing something
you didn't intend.

## Actual threat surface

- **`install.sh` writes into your `$HOME` and edits your shell profiles.** It
  symlinks into `~/.local/bin`, `~/.local/shims` and `~/.config`, and appends
  a `source` line to `~/.profile` and `~/.config/fish/config.fish`. Any real
  file already at one of those targets is moved aside to `<name>.bak` — check
  a diff of `install.sh` in any PR that touches it, since a change here runs
  with your full user permissions the next time you open a shell.
- **The shims sit ahead of the real binaries on `PATH`.** `shims/mypy` and
  `shims/biome` each `exec` the real tool after walking `PATH` to find the
  next non-shim binary. A shim that resolved the wrong binary, or that
  injected an unexpected flag, would affect every invocation of that tool in
  every project on the machine — review any change to the `PATH`-walking
  logic or the flags it injects with that in mind.
- **`install.sh --claude` patches a JSON settings file.** With `jq` available,
  it rewrites `~/.claude/settings.json`'s `env` block in place (after copying
  it to `.bak` first). A bug here could corrupt or silently alter Claude
  Code's configuration; verify any change to this path against a real
  `settings.json` before merging.
- **`bin/lintp` shells out to `ruff`, `mypy`, `oxlint` and `biome`** with
  paths and flags it builds from its arguments. ruff, mypy and biome find
  their own project config by searching upward, unchanged by `lintp`. oxlint
  only checks the cwd, so `lintp` locates the nearest `.oxlintrc.json` itself
  and passes it with `-c` — it reads that file's path, not its contents; the
  file is still parsed and applied by oxlint itself.

## What is out of scope

There are no accounts, no server component, no stored secrets, and no network
requests to report a vulnerability in — reports about those categories will
be closed as not applicable. Supply-chain concerns about `ruff`, `mypy`,
`oxlint` or `biome` themselves belong with those projects, not here.

## Reporting a vulnerability

Email **babak@cocode.dk** with a description of the issue and, if possible,
the smallest reproduction (a diff, a resulting `install.sh` state, or a
`lintp` invocation and its output). Please do not open a public issue for a
finding that could let someone else exploit it before a fix ships.

Expect an acknowledgement within a few days. This is a small, actively
maintained personal/company project, not a funded security team — there is no
bug bounty, and fix timelines depend on severity and on Babak Bandpey's
availability, but a real issue will be fixed and disclosed once it is.
