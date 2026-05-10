# src/

Top-level source directory.

## Erlang FFI files

FFI `.erl` files live here (Erlang module naming requires flat placement):

| File | Purpose |
|---|---|
| `gleeam_code_file_ffi.erl` | `file`/`filelib` wrappers (ok → {ok, nil} conversion) |
| `gleeam_code_io_ffi.erl` | `io:get_line/1` wrapper for `auth` stdin |
| `gleeam_code_submit_ffi.erl` | `os:cmd/1` and `timer:sleep/1` wrappers |
| `gleeam_code_test_runner_ffi.erl` | `eunit:test/2` wrapper |
| `gleeam_code_version_ffi.erl` | Version from `.app` metadata |

## Subdirectories

| Directory | Description |
|---|---|
| `gleeam_code/` | Gleam source modules (commands + internal). See `gleeam_code/_index.md`. |
