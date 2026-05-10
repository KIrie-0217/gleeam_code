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

## 2026-05-08: CI fix — `gleam format`

- GitHub Actions CI failed on `gleam format --check src test`
- Applied `gleam format` to all source and test files
- AGENTS.md should include: run `gleam format` before committing

## 2026-05-10: TreeNode / ListNode support (Issue #1)

### Overview

Added full support for LeetCode problems using TreeNode and ListNode data
structures. The complete pipeline works: fetch → codegen → local test → submit.

### Type system

- Gleam types: `Option(TreeNode)` / `Option(ListNode)` using `gleam/option`
- Placement: `src/types.gleam` in user's project, generated by `glc init`
- No dependency on gleeam_code package — LSP/linting works in standalone projects

### `glc init` changes

- Generates `src/types.gleam`: type definitions + `tree_from_level_order` + `list_from_list` helpers
- Generates `src/types_ffi.erl`: Erlang record ↔ Gleam type conversion functions
- Both files idempotent (skipped if already exists)

### `tree_from_level_order` algorithm

LeetCode uses BFS-serialized level-order format where null nodes' children are
omitted. Implemented two-pass approach:
1. BFS pass: builds flat index array with parent→child index pointers
2. Recursive pass: constructs tree bottom-up from flat array

Tested against: empty, single node, complete tree, null-interleaved trees,
left-skewed, full binary tree (invert_tree example).

### Codegen changes (`codegen.gleam`)

- Type mapping: `#tree_node{}`, `'null' | #tree_node{}`, `#tree_node{} | null`
  (and reversed/unquoted variants) → `Option(TreeNode)`. Same for ListNode.
- Solution generation: auto-adds `import gleam/option` and `import types` when needed
- Test generation: uses `tree_from_level_order([Some(1), None, ...])` /
  `list_from_list([1, 2, 3])` with equality comparison (`let assert True = expected == result`)
  since function calls cannot appear in `let assert` patterns

### Submit pipeline changes

- **`erlang_convert`**: now strips `-spec` lines (single and multi-line) from
  compiled Erlang. LeetCode doesn't need Gleam's internal spec annotations.
- **Project name**: reads from `gleam.toml` instead of hardcoded `gleeam_code`
  path. Required for Nix/escript-installed users.
- **`.glc_meta` file**: fetch saves `entry_function=<name>` to identify the
  LeetCode entry point. Submit reads this to generate the wrapper. Avoids
  fragile heuristics (first function, pub fn scanning).
- **Bundle (TreeNode/ListNode problems only)**:
  1. Conversion functions (`tree_to_record`/`tree_from_record`) — translates
     between Gleam `{some, {tree_node, ...}}` / `none` and LeetCode `#tree_node{}` / `null`
  2. Wrapper function with `-spec` — LeetCode calls this, it converts args,
     calls `_impl`, converts result back
  3. Renamed user function (`func_name` → `func_name_impl`)
- LeetCode provides `-record(tree_node, {...})` definition, so we don't include it

### Build path fix

- `submit.gleam` previously hardcoded `build/dev/erlang/gleeam_code/...`
- Now reads project name from `gleam.toml` to construct correct path
- Also runs `gleam build` in the user's project directory (`cd <base_dir> && ...`)

### Verification

- #226 Invert Binary Tree: Accepted (0ms, 46.9MB)
- #206 Reverse Linked List: Accepted (0ms, 49.4MB)
- 64 tests, all passing

### Known issues (separate from this feature)

- Session file occasionally empty after operations — needs investigation
- Wrapper assumes single TreeNode/ListNode argument — multi-arg problems may need enhancement

## 2026-05-10: Gleam stdlib bundler (Issue #2)

### Overview

Implemented automatic bundling of `gleam_stdlib` functions into LeetCode
submissions. Users can now write idiomatic Gleam using `list.map`, `int.to_string`,
etc., and submit successfully.

### Architecture

Three new modules in `src/gleeam_code/internal/`:

1. **`stdlib_scanner.gleam`** — scans compiled Erlang for `gleam_stdlib:func(`
   and `gleam@module:func(` patterns. Character-by-character parser that
   identifies stdlib module names and function names.

2. **`stdlib_extractor.gleam`** — extracts individual function bodies from
   stdlib `.erl` files. Parses the Gleam compiler's output structure:
   `-file(...)` delimiters → `?DOC(...)` blocks → `-spec` → function body.
   Also provides `list_exported` to distinguish public/private functions.

3. **`stdlib_bundler.gleam`** — orchestrates the full pipeline:
   - Transitive dependency resolution (worklist algorithm)
   - Local helper detection (non-exported functions called within extracted code)
   - Function renaming (`gleam@list:map` → `gleam_list__map`) to eliminate
     module-qualified calls
   - Code assembly (bundled functions + renamed solution)

### Integration

Bundler runs automatically in `submit.gleam` after `erlang_convert.convert()`:
- If no stdlib calls detected → no-op (zero overhead for pure solutions)
- If stdlib calls found → full bundle pipeline

Reads stdlib source from `build/dev/erlang/gleam_stdlib/_gleam_artefacts/`
(already present after `gleam build`).

### Design decisions

- **Rename prefix**: `module__function` (double underscore) — unambiguous,
  no collision with Erlang conventions
- **Function-level extraction** over whole-module inclusion — minimizes
  submission size for LeetCode's code limits
- **`@` → `_` in module names**: Erlang atoms with `@` are valid but
  underscore prefix is cleaner for function names

### Testing

- 77 tests, all passing (13 new tests for scanner, extractor, bundler)
- Scanner: stdlib call detection, deduplication, non-stdlib filtering
- Extractor: function extraction, multi-function, export listing, ?DOC skipping
- Bundler: no-dep passthrough, call renaming

## 2026-05-10: `glc list` command (Issue #3)

### Overview

Implemented `glc list` to display all fetched problems with submission status
and filtering capabilities.

### Features

1. **Problem listing**: scans `src/solutions/` directories, reads `solution.gleam`
   headers for number/slug/difficulty, sorts by problem number
2. **Status display**: reads `status` field from `.glc_meta` (written by `glc submit`).
   Shows `✓ Accepted`, `✗ <reason>`, or blank for unsolved problems.
3. **Difficulty filter**: `--easy`, `--medium`, `--hard` (combinable, OR logic)
4. **Status filter**: `--solved` (Accepted only), `--unsolved` (not Accepted)
5. **Combined filters**: `--easy --unsolved` applies both constraints (AND logic
   between difficulty and status groups)

### Submit integration

`glc submit` now saves result metadata to `.glc_meta` after receiving the
submission result:
- `status=Accepted` / `Wrong Answer` / `Time Limit Exceeded` / etc.
- `runtime=0 ms`
- `memory=7.2 MB`

Values are overwritten on re-submit (old status/runtime/memory lines removed first).

### Implementation

- `src/gleeam_code/list_cmd.gleam` — command logic, filter parsing, display formatting
- `src/gleeam_code/internal/file.gleam` — added `list_directory` function
- `src/gleeam_code_file_ffi.erl` — added `list_dir/1` wrapper (charlist→binary conversion)
- `src/gleeam_code/submit.gleam` — added `save_status` after poll result

### Design decisions

- **Parse from solution header** rather than `.glc_meta` for number/slug/difficulty:
  the header is always present (created by fetch), while meta may be incomplete.
  This keeps `list` working even before any submit.
- **Filter parsing is permissive**: unknown flags are silently ignored (future-proof
  for adding `--sort` etc. without breaking existing usage).
- **`Option` type for solved/unsolved**: both Off = no filter, both On = show all
  (conflicting flags cancel out rather than error).

### FFI note

`file:list_dir/1` returns charlists, not binaries. Required an FFI wrapper
(`list_dir/1` in `gleeam_code_file_ffi.erl`) to convert entries via
`unicode:characters_to_binary/1`.

### Final state

- 89 tests, all passing
- New modules: `list_cmd`
- New FFI function: `gleeam_code_file_ffi:list_dir/1`
- New test helpers: `gleeam_code_list_test_ffi.erl`

## 2026-05-10: Refactor — Extract shared internal modules

### Motivation

Multiple modules had duplicated logic that diverged slightly over time,
creating maintenance risk. Key duplications:
- `is_numeric` implemented 3 times (leetcode, submit, test_cmd)
- `resolve_module` (target → directory name) duplicated in submit and test_cmd
- `.glc_meta` key-value parsing duplicated in submit and list_cmd
- Character classification (`is_identifier_char` etc.) copied across
  stdlib_scanner, stdlib_bundler, stdlib_extractor

### New modules

1. **`internal/char.gleam`** — single source of truth for character predicates:
   `is_lowercase`, `is_uppercase`, `is_alpha`, `is_digit`, `is_identifier`,
   `is_identifier_no_at`. Replaces 5 independent re-implementations across
   stdlib_scanner, stdlib_bundler, and stdlib_extractor.

2. **`internal/resolver.gleam`** — target resolution logic shared by test_cmd
   and submit: `resolve_module(base_dir, target)` and `is_numeric(s)`.
   Replaces duplicated directory scan + number/slug matching + `is_numeric`
   in three modules (leetcode, submit, test_cmd).

3. **`internal/meta.gleam`** — `.glc_meta` file operations: `read(path)` →
   `SubmitMeta`, `find_value(lines, key)`, `save_status(path, ...)`.
   Previously `SubmitMeta` and `read_meta`/`find_meta_value`/`save_status`
   lived in submit.gleam, with a separate `find_meta_value` copy in list_cmd.

4. **`internal/spec_parser.gleam`** — Erlang spec parsing extracted from
   codegen.gleam: `parse_erlang_spec`, `erlang_type_to_gleam`, `FunctionSpec`,
   `Param`, `uses_tree_node`, `uses_list_node`, `to_snake_case`,
   `format_module_name`, `split_params`. codegen.gleam now focuses solely on
   Gleam source/test generation, importing types from spec_parser.

### Modules refactored

- **`test_cmd.gleam`**: 94 lines → 22 lines. Uses `resolver.resolve_module`.
  Deleted local `resolve_module`, `find_matching_entry`, `is_numeric_target`,
  `list_directory` FFI call.
- **`submit.gleam`**: uses `resolver.resolve_module` + `meta.read`/`meta.save_status`.
  Deleted `is_numeric`, `do_all_digits`, `resolve_module`, `find_matching_entry`,
  `find_by_number`, `find_by_slug`, `do_find`, `read_meta`, `find_meta_value`,
  `save_status`, `remove_meta_key`, `list_directory` FFI reference.
- **`list_cmd.gleam`**: uses `meta.find_value`. Deleted local `find_meta_value`.
- **`leetcode.gleam`**: uses `resolver.is_numeric`. Deleted `is_numeric` + `is_digit`.
- **`stdlib_scanner.gleam`**: uses `char.is_identifier`. Deleted 30-line `is_identifier_char`.
- **`stdlib_bundler.gleam`**: uses `char.is_lowercase`, `char.is_identifier`,
  `char.is_identifier_no_at`. Deleted `is_lower_or_underscore` (26 lines),
  `is_ident_continue` (55 lines), `is_ident_char` (57 lines).
- **`stdlib_extractor.gleam`**: uses `char.is_lowercase`. Deleted `is_lowercase_alpha` (26 lines).
- **`codegen.gleam`**: now imports `spec_parser.{type FunctionSpec, type Param}`
  and delegates `split_list_items` to `spec_parser.split_params`.
- **`fetch.gleam`**: uses `spec_parser.parse_erlang_spec` and `spec_parser.format_module_name`.

### Deleted files

- `src/gleeam_code_test_cmd_ffi.erl` — no longer needed; `resolver` uses
  `file.list_directory` which goes through `gleeam_code_file_ffi:list_dir/1`.

### Test changes

- `codegen_test.gleam` updated to import `spec_parser` for type/parser assertions.
- All 89 tests pass unchanged.

### Net effect

- ~200 lines of duplicated code eliminated
- Single point of change for module resolution, meta parsing, and char classification
- No behavior changes (pure refactor)
