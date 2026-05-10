# src/gleeam_code/internal/

Shared infrastructure modules. Not part of the public API.
Used by command modules in the parent directory (`src/gleeam_code/`).

| Module | Responsibility |
|---|---|
| `char` | Character classification (`is_lowercase`, `is_digit`, `is_identifier`) |
| `file` | File I/O via Erlang FFI |
| `config` | Session cookie read/write (`~/.gleeam/session`) |
| `resolver` | Target (slug or number) → module directory name resolution |
| `meta` | `.glc_meta` file read/write (entry function, params, submit status) |
| `spec_parser` | Erlang `-spec` line parsing, type mapping, `FunctionSpec`/`Param` types |
| `codegen` | Gleam solution/test file generation from parsed spec |
| `leetcode` | LeetCode GraphQL API client (fetch problem, resolve slug) |
| `erlang_convert` | Strip Gleam compiler directives from `.erl` output |
| `stdlib_scanner` | Detect `gleam_stdlib` / `gleam@*` calls in Erlang source |
| `stdlib_extractor` | Extract function bodies from stdlib `.erl` files |
| `stdlib_bundler` | Transitive dependency resolution + rename + single-file assembly |
| `tree_builder` | TreeNode/ListNode construction from LeetCode level-order format |
