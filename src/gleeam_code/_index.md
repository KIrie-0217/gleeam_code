# src/gleeam_code/

Command-layer modules. Each exposes a `run(base_dir, ...)` function
called from the CLI entry point (`gleeam_code.gleam`).

| Module | Command |
|---|---|
| `auth` | `glc auth` — prompt and save LeetCode session cookie |
| `fetch` | `glc fetch` — fetch problem from LeetCode, generate solution/test stubs |
| `init` | `glc init` — initialize project directories and type files |
| `list_cmd` | `glc list` — list fetched problems with status/difficulty filters |
| `submit` | `glc submit` — build, convert to Erlang, submit to LeetCode |
| `test_cmd` | `glc test` — run EUnit on a specific problem's test module |

## Subdirectories

| Directory | Description |
|---|---|
| `internal/` | Shared infrastructure modules (not public API). See `internal/_index.md`. |
