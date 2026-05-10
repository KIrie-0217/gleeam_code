# test/gleeam_code/

Unit tests for the project. Each `*_test.gleam` corresponds to a source module.

| Test file | Tests for |
|---|---|
| `auth_test` | `gleeam_code/auth` |
| `codegen_test` | `internal/codegen` + `internal/spec_parser` |
| `config_test` | `internal/config` |
| `erlang_convert_test` | `internal/erlang_convert` |
| `file_test` | `internal/file` |
| `init_test` | `gleeam_code/init` |
| `list_cmd_test` | `gleeam_code/list_cmd` |
| `route_test` | CLI routing (`gleeam_code.route`) |
| `stdlib_bundler_test` | `internal/stdlib_bundler` |
| `stdlib_extractor_test` | `internal/stdlib_extractor` |
| `stdlib_scanner_test` | `internal/stdlib_scanner` |
| `submit_bundle_test` | Submit pipeline bundling (TreeNode/ListNode wrapper generation) |
| `tree_builder_test` | `internal/tree_builder` |
