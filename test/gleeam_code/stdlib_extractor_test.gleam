import gleam/string
import gleeam_code/internal/stdlib_extractor

pub fn extract_function_finds_target_test() {
  let source =
    "-module(gleam@list).
-compile([no_auto_import]).
-export([map/2, filter/2]).

-file(\"src/gleam/list.gleam\", 100).
-spec map(list(any()), fun((any()) -> any())) -> list(any()).
map(List, Fun) ->
    lists:map(Fun, List).

-file(\"src/gleam/list.gleam\", 200).
-spec filter(list(any()), fun((any()) -> boolean())) -> list(any()).
filter(List, Pred) ->
    lists:filter(Pred, List).
"

  let assert Ok(body) = stdlib_extractor.extract_function(source, "map")
  let assert True = string.contains(body, "map(List, Fun)")
  let assert True = string.contains(body, "lists:map(Fun, List)")
}

pub fn extract_function_not_found_test() {
  let source =
    "-file(\"src/gleam/list.gleam\", 100).
-spec map(list(any()), fun((any()) -> any())) -> list(any()).
map(List, Fun) ->
    lists:map(Fun, List).
"

  let assert Error(_) = stdlib_extractor.extract_function(source, "filter")
}

pub fn extract_functions_multiple_test() {
  let source =
    "-file(\"src/gleam/list.gleam\", 100).
-spec map(list(any()), fun((any()) -> any())) -> list(any()).
map(List, Fun) ->
    lists:map(Fun, List).

-file(\"src/gleam/list.gleam\", 200).
-spec filter(list(any()), fun((any()) -> boolean())) -> list(any()).
filter(List, Pred) ->
    lists:filter(Pred, List).

-file(\"src/gleam/list.gleam\", 300).
-spec fold(list(any()), any(), fun((any(), any()) -> any())) -> any().
fold(List, Acc, Fun) ->
    lists:foldl(Fun, Acc, List).
"

  let result = stdlib_extractor.extract_functions(source, ["map", "fold"])
  let assert True = string.contains(result, "map(List, Fun)")
  let assert True = string.contains(result, "fold(List, Acc, Fun)")
  let assert False = string.contains(result, "filter(List, Pred)")
}

pub fn list_exported_test() {
  let source =
    "-module(gleam@list).
-compile([no_auto_import]).
-export([map/2, filter/2, fold/3]).

-file(\"src/gleam/list.gleam\", 100).
map(List, Fun) -> ok.
"

  let exported = stdlib_extractor.list_exported(source)
  let assert True = exported == ["map", "filter", "fold"]
}

pub fn extract_skips_doc_blocks_test() {
  let source =
    "-file(\"src/gleam/list.gleam\", 50).
?DOC(
    \" Maps a function over a list.\\n\"
).
-spec map(list(any()), fun((any()) -> any())) -> list(any()).
map(List, Fun) ->
    lists:map(Fun, List).
"

  let assert Ok(body) = stdlib_extractor.extract_function(source, "map")
  let assert True = string.contains(body, "map(List, Fun)")
  let assert False = string.contains(body, "?DOC")
}
