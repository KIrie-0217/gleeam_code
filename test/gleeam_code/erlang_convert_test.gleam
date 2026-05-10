import gleeam_code/internal/erlang_convert

pub fn convert_strips_directives_test() {
  let input =
    "-module(solutions@p0001_two_sum@solution).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, \"src/solutions/p0001_two_sum/solution.gleam\").
-export([two_sum/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    \" Problem 1: Two Sum\\n\"
    \" https://leetcode.com/problems/two-sum/\\n\"
    \" Difficulty: Easy\\n\"
).

-file(\"src/solutions/p0001_two_sum/solution.gleam\", 5).
-spec two_sum(list(integer()), integer()) -> list(integer()).
two_sum(Nums, Target) ->
    find_pair(Nums, Target, 0).
"

  let expected =
    "two_sum(Nums, Target) ->
    find_pair(Nums, Target, 0).
"

  let assert True = erlang_convert.convert(input) == expected
}

pub fn convert_preserves_multiple_functions_test() {
  let input =
    "-module(solutions@p0001_two_sum@solution).
-compile([no_auto_import]).
-define(FILEPATH, \"src/solutions/p0001_two_sum/solution.gleam\").
-export([two_sum/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    \" Problem 1: Two Sum\\n\"
).

-file(\"src/solutions/p0001_two_sum/solution.gleam\", 20).
-spec find_index(list(integer()), integer(), integer()) -> {ok, integer()} |
    {error, nil}.
find_index(Nums, Val, Start) ->
    case Nums of
        [] ->
            {error, nil};

        [X | Rest] ->
            case X =:= Val of
                true ->
                    {ok, Start};

                false ->
                    find_index(Rest, Val, Start + 1)
            end
    end.

-file(\"src/solutions/p0001_two_sum/solution.gleam\", 5).
-spec two_sum(list(integer()), integer()) -> list(integer()).
two_sum(Nums, Target) ->
    find_pair(Nums, Target, 0).
"

  let result = erlang_convert.convert(input)
  let assert True = result == "find_index(Nums, Val, Start) ->
    case Nums of
        [] ->
            {error, nil};

        [X | Rest] ->
            case X =:= Val of
                true ->
                    {ok, Start};

                false ->
                    find_index(Rest, Val, Start + 1)
            end
    end.

two_sum(Nums, Target) ->
    find_pair(Nums, Target, 0).
"
}
