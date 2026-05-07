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

## 2026-05-07: Steps 2–3 — `glc init` + `glc auth`

### `glc init`

- Module: `src/gleeam_code/init.gleam`
- Checks `gleam.toml` exists, creates `solutions/` and `.glc.toml`
- Idempotent: skips existing files/dirs without error, never overwrites `.glc.toml`

### Architecture conventions

- Command function signature: `pub fn run(base_dir, print) -> Result(Nil, String)`
- `print` callback separates IO from logic (enables testing, future `--quiet`/`--json`)
- Global `-C <dir>` option parsed before command routing via `parse_global`

### `glc auth`

- Module: `src/gleeam_code/auth.gleam`
- Extended signature: `run(_base_dir, print, read_line)` — `read_line` callback
  enables testing without stdin
- Two y/N guards before saving:
  1. If `LEETCODE_SESSION` env var exists → warn that file takes priority, confirm
  2. If `~/.gleeam/session` already exists → confirm overwrite
- FFI: `src/gleeam_code_io_ffi.erl` wraps `io:get_line/1` (returns `{ok, Data} | {error, nil}`)

### Authentication priority change

- **Before**: env var > file
- **After**: file > env var
- **Rationale**: `glc auth` is an explicit tool-specific choice. Env var may be
  set for other LeetCode CLI tools (potentially different accounts). File represents
  user's intentional gleeam_code configuration.

### Design decisions

- `read_line` as callback rather than hardcoded FFI: matches the `print` callback
  pattern for IO separation. Test FFI (`gleeam_code_auth_test_ffi.erl`) provides
  a sequential reader using message passing for multi-prompt test flows.
- y/N guards prevent accidental overwrites and inform users about priority behavior.

### Final state

- 34 tests, all passing, no warnings
- New modules: `init`, `auth`
- New FFI: `gleeam_code_io_ffi.erl` (stdin), `gleeam_code_auth_test_ffi.erl` (test helper)

## 2026-05-07: Step 4 — `glc fetch`

### Overview

Implemented full problem fetch pipeline: LeetCode GraphQL API → Erlang spec
parsing → Gleam code generation → file output.

### Module structure

- `src/gleeam_code/leetcode.gleam` — GraphQL client (HTTP + JSON decode)
- `src/gleeam_code/codegen.gleam` — Erlang spec → Gleam stub/test generation
- `src/gleeam_code/fetch.gleam` — command entry point, flow orchestration

### API findings

- LeetCode GraphQL at `https://leetcode.com/graphql` — no auth needed for free problems
- `questionContent` query returns: content (HTML), codeSnippets, exampleTestcaseList,
  questionFrontendId, titleSlug, title, difficulty, isPaidOnly
- `questionList` with `searchKeywords` resolves number → slug
- `exampleTestcaseList` contains inputs only (newline-separated per example)
- Expected outputs must be extracted from HTML `content` field

### Design decisions

- **No `problem.md`**: solution.gleam has module comment with URL + difficulty.
  User clicks URL to read full problem. Avoids HTML parsing complexity.
- **Directory layout**: `src/solutions/p0001_two_sum/solution.gleam` + matching
  `test/solutions/` — compatible with `gleam build` / `gleam test` natively.
- **Module naming**: `p` prefix required (Gleam modules must start with lowercase
  letter, not digit). Format: `p` + zero-padded 4-digit number + `_` + snake_slug.
- **Auth optional for fetch**: session attached if available, omitted otherwise.
  Premium problems detected via `content: null` + `isPaidOnly: true`.
- **Test generation**: `let assert` pattern (no testing library dependency).
  Expected outputs extracted from HTML via regex on `<strong>Output:</strong>`.
  Falls back to `todo` if extraction fails.
- **`glc init` updated**: now creates `src/solutions/` + `test/solutions/`
  instead of top-level `solutions/`.

### Erlang spec parsing

Parses `-spec` line from LeetCode's Erlang snippet:
- Splits function name, parameters (Name :: Type), return type
- Handles nested brackets for list types via depth-tracked comma splitting
- CamelCase → snake_case conversion for param names

### Type mapping (Phase 1)

| Erlang | Gleam |
|---|---|
| `integer()` | `Int` |
| `float()` | `Float` |
| `boolean()` | `Bool` |
| `unicode:chardata()` | `String` |
| `unicode:unicode_binary()` | `String` |
| `[T]` | `List(T)` (recursive) |

### Final state

- 42 tests, all passing
- New modules: `leetcode`, `codegen`, `fetch`
- Verified with: `glc fetch two-sum`, `glc fetch 14` (number → slug resolution)

## 2026-05-08: Step 5 — `glc test`

### Overview

Implemented selective test execution using EUnit directly, bypassing
`gleam test` (which has no module filter support).

### Key decisions

- **EUnit direct invocation**: `gleam test` and `gleeunit` run all tests with
  no filtering capability. `startest` package supports filtering but adds a
  dependency. EUnit can run a single module via `eunit:test(Module, Options)` —
  one FFI function suffices.
- **Module resolution by directory scan**: scans `test/solutions/` for entries
  matching the slug or number. No API call needed — works offline.
- **Same BEAM instance**: EUnit runs in-process, no subprocess spawning. Output
  goes directly to stdout.

### Implementation

- `src/gleeam_code/test_cmd.gleam` — command entry point, module resolution
- `src/gleeam_code_test_runner_ffi.erl` — wraps `eunit:test/2`, returns `{ok, nil} | {error, nil}`
- `src/gleeam_code_test_cmd_ffi.erl` — wraps `file:list_dir/1`, converts charlists to binaries

### Final state

- 42 tests, all passing
- New modules: `test_cmd`
- New FFI: `gleeam_code_test_runner_ffi.erl`, `gleeam_code_test_cmd_ffi.erl`
- Verified with: `glc test two-sum`, `glc test 1`, error case for missing problem

## 2026-05-08: Step 6 — `glc submit`

### Overview

Implemented the full submission pipeline: build → convert → submit → poll → display.
Submit API integration requires session key for live testing (deferred).

### Erlang conversion (`erlang_convert.gleam`)

Strips all Gleam-generated directives from `.erl` output:
- `-module`, `-compile`, `-define`, `-export`, `-file`
- `-if`/`-else`/`-endif` (OTP version guards)
- `?MODULEDOC(...)` / `?DOC(...)` macro invocations and their string contents

Preserves all `-spec` lines and function bodies (including private helper
functions). LeetCode's judge adds `-module(solution)` and `-export` itself.

### Submit API

- Uses REST endpoint (`/problems/<slug>/submit/`) not GraphQL
- Polls `/submissions/detail/<id>/check/` with 1s interval until state is SUCCESS
- Parses `status_msg`, `status_runtime`, `status_memory` from final response

### Design decisions

- **`os:cmd` for `gleam build`**: subprocess approach is simpler than trying
  to invoke the Gleam compiler from within the BEAM. FFI wrapper converts
  charlist return to binary.
- **Module resolution reused**: same directory scan logic as `glc test` (could
  be extracted to shared module in future, but duplication is minimal).
- **All private functions included**: LeetCode needs the complete code (not
  just the exported function). The conversion strips directives only, keeping
  all function definitions.

### Final state

- 44 tests, all passing (47 with solution test files present)
- New modules: `submit`, `erlang_convert`
- New FFI: `gleeam_code_submit_ffi.erl` (os_cmd, sleep)
- Erlang conversion verified against actual `gleam build` output
- Submit API verified with live session: two-sum Accepted (97ms, 48.6 MB)

## 2026-05-08: Refactor — `internal/` module separation

### Motivation

All modules were flat under `src/gleeam_code/`. As the project grows, separating
command-layer modules (user-facing) from infrastructure modules (internal
utilities) improves navigability and makes the public API surface explicit.

### Structure after refactor

```
src/gleeam_code/
  auth.gleam, fetch.gleam, init.gleam, submit.gleam, test_cmd.gleam  ← commands
  internal/
    codegen.gleam, config.gleam, erlang_convert.gleam, file.gleam, leetcode.gleam  ← infrastructure
```

### Changes

- Moved 5 modules to `src/gleeam_code/internal/`
- Updated all import paths (`gleeam_code/file` → `gleeam_code/internal/file`, etc.)
- Added `internal_modules` glob to `gleam.toml` to mark them non-public
- FFI `.erl` files remain in `src/` root (Erlang module naming requires flat placement)
- All 44 tests pass unchanged

## 2026-05-08: Step 7 — Versioning and distribution

### `--version` flag

- FFI: `src/gleeam_code_version_ffi.erl` — calls `application:load/1` then
  `application:get_key(gleeam_code, vsn)` to read version from `.app` metadata
- Source of truth: `gleam.toml` `version` field → compiled into `.app` by Gleam
  build tool → read at runtime via FFI. No manual synchronization needed.
- Output: `glc 1.0.0`

### gleescript escript build

- Added `gleescript` as dev dependency
- `gleam run -m gleescript` produces `./gleeam_code` (escript)
- Rename to `glc` for distribution (gleescript uses package name from gleam.toml)
- Single file, portable across any system with Erlang/OTP installed

### Nix flake

- `flake.nix` exports `packages.<system>.default` and `devShells.<system>.default`
- Builds via `gleam export erlang-shipment` (produces directory of .beam files)
- `makeWrapper` injects Erlang on PATH for the entrypoint
- Users install with `nix profile install github:KIrie-0217/gleeam_code`
- Version extracted from `gleam.toml` at eval time (no duplication)
- Verified: `nix build` + `result/bin/glc --version` → `glc 1.0.0`

### Key decision: version source

Evaluated options for `--version`:
- A) Hardcoded const — manual sync risk
- B) Build script rewrites const — CI dependency
- C) Read `gleam.toml` at runtime — file not present in escript/shipment
- D) Build-time code generation — no Gleam macro system
- **E) `.app` metadata via FFI** — chosen. Zero maintenance, works in all
  distribution formats (dev, escript, erlang-shipment, Nix)

### Final state

- 44 tests, all passing
- New FFI: `gleeam_code_version_ffi.erl`
- New files: `flake.nix`, `flake.lock`
- New dependency: `gleescript` (dev only)
- Verified on: `gleam run`, gleescript escript, Nix build
