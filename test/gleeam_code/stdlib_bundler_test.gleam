import gleam/string
import gleeam_code/internal/stdlib_bundler

pub fn bundle_no_deps_unchanged_test() {
  let input =
    "two_sum(Nums, Target) ->
    find_pair(Nums, Target, 0).
"
  let result = stdlib_bundler.bundle(input, "/nonexistent")
  let assert True = result == input
}

pub fn bundle_renames_stdlib_calls_test() {
  let input =
    "solve(X) ->
    gleam_stdlib:identity(X).
"
  let stdlib_dir = "build/dev/erlang/gleam_stdlib/_gleam_artefacts"
  let result = stdlib_bundler.bundle(input, stdlib_dir)
  let assert True = string.contains(result, "gleam_stdlib__identity(")
  let assert False = string.contains(result, "gleam_stdlib:identity(")
}

pub fn bundle_renames_module_calls_test() {
  let input =
    "solve(List) ->
    gleam@list:map(List, fun(X) -> X + 1 end).
"
  let stdlib_dir = "build/dev/erlang/gleam_stdlib/_gleam_artefacts"
  let result = stdlib_bundler.bundle(input, stdlib_dir)
  let assert True = string.contains(result, "gleam_list__map(")
  let assert False = string.contains(result, "gleam@list:map(")
}
