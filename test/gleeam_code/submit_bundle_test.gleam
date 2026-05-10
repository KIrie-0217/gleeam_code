import gleam/string
import gleeam_code/internal/erlang_convert

pub fn convert_tree_node_solution_test() {
  let input =
    "-module(solutions@p0226_invert_binary_tree@solution).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, \"src/solutions/p0226_invert_binary_tree/solution.gleam\").
-export([invert_tree/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    \" Problem 226: Invert Binary Tree\\n\"
).

-file(\"src/solutions/p0226_invert_binary_tree/solution.gleam\", 8).
-spec invert_tree(gleam@option:option(types:tree_node())) -> gleam@option:option(types:tree_node()).
invert_tree(Root) ->
    case Root of
        none ->
            none;

        {some, Node} ->
            {some,
                {tree_node,
                    erlang:element(2, Node),
                    invert_tree(erlang:element(4, Node)),
                    invert_tree(erlang:element(3, Node))}}
    end.
"

  let result = erlang_convert.convert(input)
  let assert True = string.starts_with(result, "invert_tree(Root)")
  let assert False = string.contains(result, "-spec")
  let assert False = string.contains(result, "-module")
  let assert True = string.contains(result, "case Root of")
}
