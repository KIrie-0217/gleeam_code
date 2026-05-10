import gleam/list
import gleeam_code/internal/stdlib_scanner.{StdlibCall}

pub fn scan_detects_gleam_stdlib_calls_test() {
  let input =
    "two_sum(Nums, Target) ->
    gleam_stdlib:string_starts_with(Nums, <<\"hello\">>).
"
  let result = stdlib_scanner.scan(input)
  let assert True =
    list.contains(
      result,
      StdlibCall(module: "gleam_stdlib", function: "string_starts_with"),
    )
}

pub fn scan_detects_gleam_module_calls_test() {
  let input =
    "solve(List) ->
    gleam@list:map(List, fun(X) -> X + 1 end).
"
  let result = stdlib_scanner.scan(input)
  let assert True =
    list.contains(result, StdlibCall(module: "gleam@list", function: "map"))
}

pub fn scan_detects_multiple_calls_test() {
  let input =
    "solve(A, B) ->
    X = gleam@list:filter(A, fun(I) -> I > 0 end),
    Y = gleam@int:to_string(B),
    gleam_stdlib:identity(Y).
"
  let result = stdlib_scanner.scan(input)
  let assert True =
    list.contains(result, StdlibCall(module: "gleam@list", function: "filter"))
  let assert True =
    list.contains(
      result,
      StdlibCall(module: "gleam@int", function: "to_string"),
    )
  let assert True =
    list.contains(
      result,
      StdlibCall(module: "gleam_stdlib", function: "identity"),
    )
}

pub fn scan_ignores_non_stdlib_modules_test() {
  let input =
    "foo(X) ->
    erlang:length(X),
    lists:sort(X).
"
  let result = stdlib_scanner.scan(input)
  let assert True = result == []
}

pub fn scan_deduplicates_test() {
  let input =
    "f(A, B) ->
    gleam@list:map(A, fun(X) -> X end),
    gleam@list:map(B, fun(Y) -> Y end).
"
  let result = stdlib_scanner.scan(input)
  let map_calls =
    list.filter(result, fn(c) {
      c.module == "gleam@list" && c.function == "map"
    })
  let assert True = list.length(map_calls) == 1
}
