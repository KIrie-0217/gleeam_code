-module(gleeam_code_test_runner_ffi).
-export([run_eunit/1]).

run_eunit(Module) ->
    case eunit:test(Module, [verbose]) of
        ok -> {ok, nil};
        error -> {error, nil}
    end.
