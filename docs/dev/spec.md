# gleeam_code Specification

## Implementation Status

### Phase 1 (MVP)

- [x] Project foundation (dependencies, gleam.toml)
- [x] File I/O module (`file.gleam` + `gleeam_code_file_ffi.erl`)
- [x] Config module (`config.gleam` — session read/write, env var fallback)
- [x] CLI entry point (argv + route, testable)
- [ ] `glc init` — create `solutions/`, `.glc.toml`, check `gleam.toml`
- [ ] `glc auth` — prompt and save session cookie
- [ ] `glc fetch` — LeetCode GraphQL client, stub/test/problem generation
- [ ] `glc test` — run `gleam test` for a specific problem
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

- Creates `solutions/` directory
- Creates `.glc.toml` (project-level config)
- Errors if `gleam.toml` is not found (guide user to run `gleam new` first)

### `glc auth`

Prompt the user to paste their `LEETCODE_SESSION` cookie and save it to `~/.gleeam/config.toml`.

### `glc fetch <slug-or-number>`

Fetch a problem from LeetCode and generate solution files.

- Accepts either a problem slug (`two-sum`) or number (`1`)
- Creates `solutions/<0001>-<slug>/` directory with:
  - `solution.gleam` — function stub
  - `solution_test.gleam` — sample test cases
  - `problem.md` — problem description

### `glc test <slug-or-number>`

Build and run tests for a specific problem.

- Wraps `gleam test` targeting the specific problem's test file

### `glc submit <slug-or-number>`

Build Gleam source, convert to Erlang, and submit to LeetCode.

- Compile via `gleam build --target erlang`
- Post-process the generated `.erl` file (see Erlang Conversion)
- Submit as Erlang (`langSlug: "erlang"`) via LeetCode GraphQL API
- Display submission result (accepted, wrong answer, runtime, etc.)

## Authentication

Priority order:
1. Environment variable `LEETCODE_SESSION`
2. Config file `~/.gleeam/config.toml`

Config file format:
```toml
[auth]
leetcode_session = "<cookie value>"
```

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

```
solutions/
├── 0001-two-sum/
│   ├── solution.gleam
│   ├── solution_test.gleam
│   └── problem.md
├── 0002-add-two-numbers/
│   ├── solution.gleam
│   ├── solution_test.gleam
│   └── problem.md
```

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

## Implementation Plan

### Step 1: Project foundation

- Add dependencies to `gleam.toml`
- CLI entry point with `argv` + `case` routing for subcommands
- File I/O module: thin `@external` wrappers over Erlang `file`/`filelib`
- Config module: read/write `~/.gleeam/session` (plain text, cookie only)
- Credential resolver: env var `LEETCODE_SESSION` → config file fallback

### Step 2: `glc init`

- Check `gleam.toml` exists in current directory
- Create `solutions/` directory
- Create `.glc.toml` marker file

### Step 3: `glc auth`

- Prompt user to paste `LEETCODE_SESSION` cookie via stdin
- Save to `~/.gleeam/session`

### Step 4: `glc fetch`

- LeetCode GraphQL client: query `questionContent` by slug or number
- Parse response: extract Erlang code snippet, example test cases, problem HTML
- Generate `solutions/<0001>-<slug>/solution.gleam` (Gleam stub from Erlang spec)
- Generate `solutions/<0001>-<slug>/solution_test.gleam` (sample test cases)
- Generate `solutions/<0001>-<slug>/problem.md` (HTML → plain text conversion)

### Step 5: `glc test`

- Locate test file for the given problem
- Run `gleam test` as subprocess

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
- `glc fetch` — fetch problem, generate Gleam stub + tests + problem.md
- `glc test` — run local tests
- `glc submit` — Erlang conversion (strip module/export only) + submit
- Gleam stdlib usage: not supported. Users write pure Gleam or use `@external` for Erlang stdlib calls.

### Phase 2

- TreeNode / ListNode support with Gleam type definitions and Erlang record conversion
- Gleam stdlib bundler: detect and inline used `gleam_stdlib` functions
- `glc list` — list fetched problems
- Remote test execution via `interpretSolution`
