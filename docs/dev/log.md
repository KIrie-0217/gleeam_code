# Development Log

## 2026-05-01: Specification

- Defined project scope: Gleam CLI tool for LeetCode (fetch, test, submit)
- Investigated LeetCode GraphQL API (problem fetch, code snippets, submit)
- Confirmed LeetCode Erlang template format via API (`-spec` + body only, no `-module`)
- Confirmed TreeNode/ListNode use Erlang records (deferred to Phase 2)
- Decided CLI command name: `glc` (avoids `gleam`/`gleeam` typo confusion, no conflicts)
- Decided directory structure: `solutions/<0001>-<slug>/`
- Decided authentication: env var `LEETCODE_SESSION` → `~/.gleeam/session` file
- Added `glc init` command (requires existing `gleam.toml`)
- Created spec.md and updated AGENTS.md

## 2026-05-02: Step 1 — Project Foundation

### Dependency selection

- Started with plan: official packages only + `argv` + self-implemented file I/O
- Evaluated `simplifile` (135 stars, Apache-2.0, 173 dependants) and `glint` (79 stars, Apache-2.0)
- Decided against both: `glint` is overkill for 5 subcommands, file I/O needs only 5 functions
- Discovered `gleam_erlang` v1.0 removed its `os` module; added `envoy` (lpil, Apache-2.0) for env vars
- Final dependencies: 6 official + 2 Gleam-author packages (`argv`, `envoy`)

### File I/O module

- Initial attempt: direct `@external` to Erlang `file` module with `Result` return type
- **Problem**: Erlang `file:write_file/2` returns bare `ok` atom, not `{ok, nil}` tuple.
  Gleam `Result` maps to `{ok, V} | {error, E}`, causing `CaseClause(Ok)` at runtime.
- Considered Gleam-side fix with `Dynamic` decoding, but wiki anti-patterns says
  "No `Dynamic` for FFI" — use specific types instead.
- **Solution**: Erlang FFI wrapper (`gleeam_code_file_ffi.erl`) that converts `ok` → `{ok, nil}`.
  Clean room implementation from Erlang official documentation only.

### Config module

- Home directory: `envoy.get("HOME")` (no Gleam stdlib function for this; Windows deferred)
- Session storage: plain text file `~/.gleeam/session` (no TOML parser needed)
- Credential resolution: env var → file fallback

### CLI entry point

- Initial version had all logic in `main()` — not testable
- Refactored: `route(args) -> Result(Command, String)` for testable routing

### AGENTS.md improvements

Added development guidelines based on mistakes encountered:
- Consult wiki before writing code (especially FFI pages)
- Verify Erlang function return values before writing `@external` bindings
- Dependency evaluation checklist
- Module-first development flow (implement → test → next)
- Living document improvement process

### Final state

- 19 tests, all passing, no warnings
- Modules: `file`, `config`, CLI routing
