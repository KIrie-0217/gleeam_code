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
- [ ] `glc submit` — Erlang conversion + LeetCode submit + result display

### Phase 2

- [ ] TreeNode / ListNode support
- [ ] Gleam stdlib bundler (inline used functions for LeetCode submission)
- [ ] `glc list` — list fetched problems
- [ ] Remote test execution (`interpretSolution`)
- [ ] Windows support (`USERPROFILE` for home directory)
- [ ] `glc` escript binary via `gleescript` (lpil)
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

### Building as standalone binary (Phase 2)

Uses `gleescript` (lpil) to produce an escript binary. Requires Erlang/OTP on the host.

```sh
gleam run -m gleescript          # produces ./glc escript
./glc fetch two-sum
```

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

All command modules (`init`, `auth`, `fetch`, `test`, `submit`) follow this
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
- `src/gleeam_code/leetcode.gleam` — GraphQL client (HTTP request + JSON parse)
- `src/gleeam_code/codegen.gleam` — Erlang spec → Gleam stub/test generation

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
- Resolves slug/number → module name by scanning `test/solutions/` directory
- Runs EUnit directly on the target module via FFI (`eunit:test/2`)
- FFI: `src/gleeam_code_test_runner_ffi.erl` (EUnit), `src/gleeam_code_test_cmd_ffi.erl` (directory listing)
- No subprocess needed — EUnit runs in the same BEAM instance

### Step 6: `glc submit`

- Run `gleam build --target erlang`
- Read generated `.erl` file
- Strip `-module`, `-compile`, `-define`, `-file`, `-export` directives
- Extract target function's `-spec` and body
- Submit via LeetCode GraphQL API (`lang: "erlang"`)
- Poll for result and display (accepted/wrong answer/runtime/memory)

## Phased Implementation

### Phase 1 (MVP)

Target: array, string, and numeric problems (no TreeNode/ListNode).

- `glc init` — initialize project (create `solutions/`, `.glc.toml`)
- `glc auth` — save cookie
- `glc fetch` — fetch problem, generate Gleam stub + tests (auth optional for free problems)
- `glc test` — run local tests
- `glc submit` — Erlang conversion (strip module/export only) + submit
- Gleam stdlib usage: not supported. Users write pure Gleam or use `@external` for Erlang stdlib calls.

### Phase 2

- TreeNode / ListNode support with Gleam type definitions and Erlang record conversion
- Gleam stdlib bundler: detect and inline used `gleam_stdlib` functions
- `glc list` — list fetched problems
- Remote test execution via `interpretSolution`
