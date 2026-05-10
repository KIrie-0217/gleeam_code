# gleeam_code Specification

## Implementation Status

### Phase 1 (MVP)

- [x] Project foundation (dependencies, gleam.toml)
- [x] File I/O module (`file.gleam` + `gleeam_code_file_ffi.erl`)
- [x] Config module (`config.gleam` — session read/write, file > env var priority)
- [x] CLI entry point (argv + route, testable)
- [x] `glc init` — create `solutions/`, `.glc.toml`, check `gleam.toml`
- [x] Global `-C <dir>` option + `parse_global` + Architecture conventions
- [x] `glc auth` — prompt and save session cookie (with y/N guards)
- [x] `glc fetch` — LeetCode GraphQL client, Gleam stub + test generation
- [x] `glc test` — run EUnit for a specific problem's test module
- [x] `glc submit` — Erlang conversion + LeetCode submit + result display
- [x] `--version` flag (runtime version from `.app` metadata via FFI)
- [x] `gleescript` escript build (standalone `glc` binary)
- [x] `flake.nix` for Nix distribution

### Phase 2

- [ ] TreeNode / ListNode support
- [x] Gleam stdlib bundler (inline used functions for LeetCode submission)
- [x] `glc list` — list fetched problems with status display and filters
- [ ] Remote test execution (`interpretSolution`)
- [ ] Windows support (`USERPROFILE` for home directory)
- [ ] Shell completion (`glc completion bash/zsh/fish`)

## Overview

A Gleam CLI tool for solving LeetCode problems.
Write solutions in Gleam, compile to Erlang, and submit to LeetCode as Erlang.

- CLI command: `glc`
- Package name: `gleeam_code`

### Running (development)

```sh
gleam run -- <command> [args]    # e.g. gleam run -- fetch two-sum
```

### Building as standalone binary

Uses `gleescript` (lpil) to produce an escript binary. Requires Erlang/OTP on the host.

```sh
gleam run -m gleescript          # produces ./glc escript
./glc fetch two-sum
```

### Installing via Nix

```sh
nix profile install github:KIrie-0217/gleeam_code
glc fetch two-sum
```

Or in a user's `flake.nix`:
```nix
inputs.gleeam_code.url = "github:KIrie-0217/gleeam_code";
# then: gleeam_code.packages.${system}.default
```

## Versioning

Source of truth: `version` field in `gleam.toml`.

The Gleam build tool embeds this into the `.app` metadata file. At runtime,
`application:get_key(gleeam_code, vsn)` retrieves it via FFI — no manual
synchronization needed.

```sh
glc --version   # → "glc 0.1.0"
```

## Distribution

| Channel | Method | User requirement |
|---|---|---|
| Source | `git clone` + `gleam run -m gleescript` | Gleam + Erlang |
| GitHub Releases | Download `glc` escript | Erlang |
| Nix flake | `nix profile install github:...` | Nix |

## Commands

### `glc init`

Initialize the current directory for glc use. Requires an existing Gleam project (`gleam.toml`).

- Checks `base_dir/gleam.toml` exists → Error if not found
- Creates `base_dir/src/solutions/` directory (skip if exists, idempotent)
- Creates `base_dir/test/solutions/` directory (skip if exists, idempotent)
- Creates `base_dir/.glc.toml` (skip if exists, never overwrite)
- Each step notifies via `print` on creation or skip
- Error message: `"gleam.toml not found. Run 'gleam new <project>' first."`

`.glc.toml` initial content:
```toml
# glc project config
[project]
solutions_dir = "solutions"
```

### `glc auth`

Prompt the user to paste their `LEETCODE_SESSION` cookie and save it to `~/.gleeam/session`.

- If `LEETCODE_SESSION` env var is already set:
  - Warn that the session file takes higher priority
  - Prompt `Save a separate session anyway? [y/N]` → N aborts
- If `~/.gleeam/session` already exists:
  - Prompt `Overwrite? [y/N]` → N aborts
- Prompt to paste cookie → trim → save to `~/.gleeam/session`
- Empty input → error, session not saved

### `glc list [options]`

List all fetched problems with their status.

- Scans `src/solutions/` for problem directories
- Reads solution header for number, slug, difficulty
- Reads `.glc_meta` for submission status (updated by `glc submit`)
- Display as a formatted table with columns: #, Slug, Difficulty, Status

#### Filter options

| Flag | Effect |
|---|---|
| `--easy` | Show only Easy problems |
| `--medium` | Show only Medium problems |
| `--hard` | Show only Hard problems |
| `--solved` | Show only Accepted problems |
| `--unsolved` | Show problems not yet Accepted |

Filters are combinable: `glc list --easy --unsolved` shows Easy problems that
haven't been solved yet. Multiple difficulty flags are OR'd (`--easy --medium`
shows both).

#### Example output

```
#    Slug                          Difficulty  Status
1    two-sum                       Easy        ✓ Accepted
14   longest-common-prefix         Easy
53   maximum-subarray              Medium      ✗ Wrong Answer
```

### `glc fetch <slug-or-number>`

Fetch a problem from LeetCode and generate solution files.

- Accepts either a problem slug (`two-sum`) or number (`1`)
- Authentication is optional for free problems; required for Premium
- Creates files in Gleam project structure:
  - `src/solutions/p0001_two_sum/solution.gleam` — module comment (URL, difficulty) + function stub
  - `test/solutions/p0001_two_sum/solution_test.gleam` — sample test cases with expected outputs
- Module naming: `p` prefix + zero-padded number + snake_case slug (Gleam requires lowercase letter start)
- Expected outputs extracted from HTML content via regex (`<strong>Output:</strong>`)
  - Fallback to `todo` if extraction fails

#### Premium problem handling

| Condition | Behavior |
|---|---|
| `content` present | Normal processing |
| `content: null` + `isPaidOnly: true` + no auth | Error: `"Premium problem. Run 'glc auth' to authenticate."` |
| `content: null` + `isPaidOnly: true` + auth present | Error: `"Premium problem. Your account may not have Premium access."` |
| `content: null` + other | Error: `"Failed to fetch problem content."` |

### `glc test <slug-or-number>`

Run tests for a specific problem using EUnit directly.

- Resolves slug or number to module name by scanning `test/solutions/`
- Executes EUnit on the specific test module (not all tests)
- Accepts slug (`two-sum`) or number (`1`)
- Error if problem not fetched yet: `"Problem not found: <target>. Run 'glc fetch <target>' first."`

### `glc submit <slug-or-number>`

Build Gleam source, convert to Erlang, and submit to LeetCode.

- Compile via `gleam build --target erlang`
- Post-process the generated `.erl` file (see Erlang Conversion)
- Submit as Erlang (`langSlug: "erlang"`) via LeetCode GraphQL API
- Display submission result (accepted, wrong answer, runtime, etc.)
- Save result to `.glc_meta`: `status`, `runtime`, `memory` fields
  (overwrites previous values on re-submit)

## Authentication

Priority order:
1. Session file `~/.gleeam/session` (plain text, cookie value only)
2. Environment variable `LEETCODE_SESSION` (fallback)

The session file takes priority because `glc auth` represents an explicit,
tool-specific choice by the user. The env var serves as a fallback for users
who already have it set for other LeetCode CLI tools.

## LeetCode API

All communication uses the GraphQL endpoint at `https://leetcode.com/graphql`.

### Fetch problem

Query `questionContent` with `titleSlug` to retrieve:
- `content` — problem description (HTML)
- `codeSnippets` — code templates per language (extract `erlang`)
- `exampleTestcaseList` — sample test inputs
- `questionFrontendId` — problem number
- `titleSlug` — URL slug

### Submit solution

Mutation `problemsSubmit` with:
- `titleSlug`
- `lang: "erlang"`
- `typed_code` — the converted Erlang code

### Test solution (remote)

Mutation `interpretSolution` for remote test execution (future consideration).

## Directory Structure

Solution files live inside Gleam's standard `src/` and `test/` directories
so that `gleam build` and `gleam test` work without extra tooling.

```
src/solutions/
├── p0001_two_sum/
│   └── solution.gleam
├── p0002_add_two_numbers/
│   └── solution.gleam

test/solutions/
├── p0001_two_sum/
│   └── solution_test.gleam
├── p0002_add_two_numbers/
│   └── solution_test.gleam
```

Module naming convention: `p` + zero-padded number (4 digits) + `_` + snake_case slug.
Gleam module names must start with a lowercase letter and contain only
lowercase alphanumeric characters or underscores.

## Erlang Conversion

### LeetCode Erlang Template Format

LeetCode expects Erlang code **without** `-module` and `-export` directives.
These are added automatically by LeetCode's judge.

Example (Two Sum):
```erlang
-spec two_sum(Nums :: [integer()], Target :: integer()) -> [integer()].
two_sum(Nums, Target) ->
  .
```

Example (Add Two Numbers — LinkedList):
```erlang
%% Definition for singly-linked list.
%%
%% -record(list_node, {val = 0 :: integer(),
%%                     next = null :: 'null' | #list_node{}}).

-spec add_two_numbers(L1 :: #list_node{} | null, L2 :: #list_node{} | null) -> #list_node{} | null.
add_two_numbers(L1, L2) ->
  .
```

Example (Invert Binary Tree — TreeNode):
```erlang
%% Definition for a binary tree node.
%%
%% -record(tree_node, {val = 0 :: integer(),
%%                     left = null  :: 'null' | #tree_node{},
%%                     right = null :: 'null' | #tree_node{}}).

-spec invert_tree(Root :: #tree_node{} | null) -> #tree_node{} | null.
invert_tree(Root) ->
  .
```

### Conversion Steps

1. `gleam build --target erlang` generates `.erl` in `build/dev/erlang/gleeam_code/_gleam_artefacts/`
2. Strip `-module(...)`, `-compile(...)`, `-define(...)`, `-file(...)` directives
3. Strip `-export(...)` directive
4. Extract the target function's `-spec` and body

### Gleam Standard Library Dependency

Gleam compiles to its own Erlang modules (`gleam_stdlib`, `gleam@list`, `gleam@dict`, etc.),
**not** to Erlang standard library calls. Since LeetCode requires single-file submission,
any `gleam_stdlib` usage requires bundling.

#### Stdlib Bundler (implemented)

The bundler runs automatically during `glc submit` after Erlang conversion:

1. **Scan** — detect `gleam_stdlib:func(` and `gleam@module:func(` calls in the converted code
2. **Resolve** — transitively resolve dependencies (stdlib functions that call other stdlib functions)
3. **Extract** — pull function bodies from `build/dev/erlang/gleam_stdlib/_gleam_artefacts/`
4. **Rename** — prefix all functions to avoid module boundaries (`gleam@list:map` → `gleam_list__map`)
5. **Assemble** — concatenate bundled functions + renamed solution into a single submission

Modules:
- `src/gleeam_code/internal/stdlib_scanner.gleam` — dependency detection
- `src/gleeam_code/internal/stdlib_extractor.gleam` — function body extraction from .erl files
- `src/gleeam_code/internal/stdlib_bundler.gleam` — orchestration (resolve + rename + assemble)

## Type Mapping

| LeetCode Erlang | Gleam |
|---|---|
| `integer()` | `Int` |
| `float()` | `Float` |
| `boolean()` | `Bool` |
| `char()` (integer) | `Int` |
| `unicode:chardata()` (string) | `String` |
| `[integer()]` | `List(Int)` |
| `[unicode:chardata()]` | `List(String)` |
| `#list_node{}` | TBD (Phase 2) |
| `#tree_node{}` | TBD (Phase 2) |

## Dependencies

| Package | Source | Purpose |
|---|---|---|
| `gleam_stdlib` | gleam-lang (official) | Standard library |
| `gleam_http` | gleam-lang (official) | HTTP types (dependency of httpc) |
| `gleam_httpc` | gleam-lang (official) | HTTP client (Erlang httpc-based) |
| `gleam_json` | gleam-lang (official) | JSON encode/decode |
| `gleam_erlang` | gleam-lang (official) | Atom type, OS command execution |
| `argv` | lpil (Gleam author) | Cross-platform argument retrieval |
| `envoy` | lpil (Gleam author) | Environment variable access |

No other third-party dependencies. File I/O uses a thin `@external` wrapper
over Erlang's `file`/`filelib` modules. CLI routing uses `argv` + pattern matching.
Config file is plain text (no TOML parser needed).

### Design decisions

- **Home directory**: Retrieved via `envoy.get("HOME")`. Gleam has no standard
  library function for home directory or XDG paths. Erlang's `filename:basedir`
  exists but would require FFI. `HOME` env var is sufficient for macOS/Linux.
  Windows support (`USERPROFILE`) deferred to Phase 2.
- **Environment variables**: `gleam_erlang` removed its `os` module in v1.0.0.
  `envoy` is the Gleam author's replacement package (Apache-2.0, 48 dependants).
- **File I/O**: Self-implemented via Erlang FFI rather than using `simplifile`.
  Only 5 functions needed; Erlang `file`/`filelib` modules provide the primitives
  directly. See `src/gleeam_code_file_ffi.erl`.

## Architecture

### Command function signature

All command modules (`init`, `auth`, `fetch`, `test`, `submit`, `list_cmd`) follow this
pattern:

```gleam
pub fn run(base_dir: String, print: fn(String) -> Nil) -> Result(Nil, String)
```

- `base_dir`: working directory for the command (main passes `"."` or the
  value from `-C`)
- `print`: callback for progress messages. Main passes `io.println`; tests
  pass a mock/no-op function
- `Result(Nil, String)`: Ok = completed, Error = abort reason
- Commands do NOT call `io.println` directly — all user-facing output goes
  through `print`

This separates IO concerns from logic, enables unit testing without side
effects, and allows future output modes (e.g. `--quiet`, `--json`) by
swapping the `print` function.

### Internal module structure

Shared utilities live in `src/gleeam_code/internal/`:

| Module | Responsibility |
|---|---|
| `char.gleam` | Character classification (`is_lowercase`, `is_digit`, `is_identifier`, etc.) |
| `file.gleam` | File I/O via Erlang FFI |
| `config.gleam` | Session cookie read/write |
| `resolver.gleam` | Target → module name resolution, `is_numeric` (shared by test_cmd, submit) |
| `meta.gleam` | `.glc_meta` file read/write (`SubmitMeta`, `find_value`, `save_status`) |
| `spec_parser.gleam` | Erlang `-spec` parsing, type mapping, `FunctionSpec`/`Param` types |
| `codegen.gleam` | Gleam source/test file generation |
| `leetcode.gleam` | LeetCode GraphQL API client |
| `erlang_convert.gleam` | Strip Gleam directives from compiled `.erl` |
| `stdlib_scanner.gleam` | Detect stdlib calls in Erlang source |
| `stdlib_extractor.gleam` | Extract function bodies from stdlib `.erl` files |
| `stdlib_bundler.gleam` | Transitive resolve + rename + assemble stdlib bundle |
| `tree_builder.gleam` | TreeNode/ListNode construction from level-order |

### Global options

```
glc [-C <dir>] <command> [args]
```

- `-C <dir>`: set the working directory (default: `"."`)
- Global options are parsed before command routing via `parse_global`

```gleam
pub type GlobalOpts {
  GlobalOpts(directory: String)
}

pub fn parse_global(args: List(String)) -> #(GlobalOpts, List(String))
```

The `directory` value is passed as `base_dir` to each command's `run()`.

## Implementation Plan

### Step 1: Project foundation

- Add dependencies to `gleam.toml`
- CLI entry point with `argv` + `case` routing for subcommands
- File I/O module: thin `@external` wrappers over Erlang `file`/`filelib`
- Config module: read/write `~/.gleeam/session` (plain text, cookie only)
- Credential resolver: env var `LEETCODE_SESSION` → config file fallback

### Step 2: `glc init`

- Module: `src/gleeam_code/init.gleam`
- Signature: `pub fn run(base_dir: String, print: fn(String) -> Nil) -> Result(Nil, String)`
- Check `base_dir/gleam.toml` exists (via `file.exists`)
- Create `base_dir/solutions/` (via `file.mkdir`, skip if exists)
- Create `base_dir/.glc.toml` with initial content (via `file.write`, skip if exists)
- Tests: `test/gleeam_code/init_test.gleam` — uses temp directory as `base_dir`

### Step 3: `glc auth`

- Module: `src/gleeam_code/auth.gleam`
- Signature: `pub fn run(_base_dir: String, print: fn(String) -> Nil, read_line: fn(String) -> Result(String, Nil)) -> Result(Nil, String)`
- `read_line` callback: production uses Erlang FFI (`io:get_line/1`), tests pass mock functions
- Guards: env var existence check (y/N), session file existence check (y/N)
- Save to `~/.gleeam/session` via `config.save_session`
- FFI: `src/gleeam_code_io_ffi.erl` — wraps `io:get_line/1`
- Tests: `test/gleeam_code/auth_test.gleam` — uses sequential reader FFI for multi-prompt flows

### Step 4: `glc fetch`

Modules:
- `src/gleeam_code/fetch.gleam` — command entry point (`run`)
- `src/gleeam_code/internal/leetcode.gleam` — GraphQL client (HTTP request + JSON parse)
- `src/gleeam_code/internal/spec_parser.gleam` — Erlang spec parsing, type mapping, FunctionSpec/Param types
- `src/gleeam_code/internal/codegen.gleam` — Gleam stub/test generation (uses spec_parser types)

Flow:
1. Resolve input (slug or number) → `titleSlug`
2. Get session (optional — proceed without for free problems)
3. GraphQL query `questionContent` → parse JSON response
4. Extract Erlang code snippet from `codeSnippets` (lang: `"erlang"`)
5. Parse `-spec` line: function name, arg names+types, return type
6. Convert Erlang types → Gleam types (Phase 1: integer, float, boolean, string, lists)
7. Extract expected outputs from HTML via regex (`<strong>Output:</strong>`)
8. Generate `src/solutions/p<NNNN>_<slug>/solution.gleam` (module comment + stub)
9. Generate `test/solutions/p<NNNN>_<slug>/solution_test.gleam` (example tests)

Testing strategy:
- Unit tests for JSON parsing (hardcoded response fixtures)
- Unit tests for codegen (Erlang spec → Gleam code)
- Integration test: manual (actual API call)

### Step 5: `glc test`

- Module: `src/gleeam_code/test_cmd.gleam`
- Signature: `pub fn run(base_dir: String, target: String, print: fn(String) -> Nil) -> Result(Nil, String)`
- Resolves slug/number → module name via `internal/resolver.gleam`
- Runs EUnit directly on the target module via FFI (`eunit:test/2`)
- FFI: `src/gleeam_code_test_runner_ffi.erl` (EUnit)
- No subprocess needed — EUnit runs in the same BEAM instance

### Step 6: `glc submit`

- Module: `src/gleeam_code/submit.gleam`
- Signature: `pub fn run(base_dir: String, target: String, print: fn(String) -> Nil) -> Result(Nil, String)`
- Erlang conversion: `src/gleeam_code/erlang_convert.gleam`
- FFI: `src/gleeam_code_submit_ffi.erl` (os:cmd wrapper, timer:sleep wrapper)

Flow:
1. Require session (error if not set)
2. Resolve module name (directory scan, same as `glc test`)
3. `gleam build --target erlang` via `os:cmd`
4. Read `.erl` from `build/dev/erlang/gleeam_code/_gleam_artefacts/`
5. Strip directives: `-module`, `-compile`, `-define`, `-export`, `-file`,
   `-if`/`-else`/`-endif`, `?MODULEDOC(...)` blocks
6. POST to `/problems/<slug>/submit/` (not GraphQL — REST endpoint)
7. Poll `/submissions/detail/<id>/check/` until state is SUCCESS
8. Display result (Accepted/Wrong Answer + runtime + memory)

### Step 7: Versioning and distribution

- `--version` flag: FFI via `application:get_key(gleeam_code, vsn)` after `application:load/1`
- FFI: `src/gleeam_code_version_ffi.erl` — returns version string from `.app` metadata
- `gleescript` added as dev dependency, produces `./glc` escript
- `flake.nix` at repo root: exports `packages.<system>.default`
  - Builds via `gleam export erlang-shipment`
  - Wraps entrypoint with `makeWrapper` to inject Erlang on PATH
  - Also provides `devShells.default` with gleam + erlang

## Phased Implementation

### Phase 1 (MVP)

Target: array, string, and numeric problems (no TreeNode/ListNode).

- `glc init` — initialize project (create `solutions/`, `.glc.toml`)
- `glc auth` — save cookie
- `glc fetch` — fetch problem, generate Gleam stub + tests (auth optional for free problems)
- `glc test` — run local tests
- `glc submit` — Erlang conversion (strip module/export only) + submit
- `glc --version` — runtime version from `.app` metadata
- Distribution: gleescript escript + Nix flake
- Gleam stdlib usage: not supported. Users write pure Gleam or use `@external` for Erlang stdlib calls.

### Phase 2

- TreeNode / ListNode support with Gleam type definitions and Erlang record conversion
- Gleam stdlib bundler: detect and inline used `gleam_stdlib` functions
- `glc list` — list fetched problems with status display and difficulty/status filters
- Remote test execution via `interpretSolution`
