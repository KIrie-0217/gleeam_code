-module(gleeam_code_auth_test_ffi).
-export([make_sequential_reader/1]).

make_sequential_reader(Responses) ->
    Pid = spawn(fun() -> reader_loop(Responses) end),
    fun(_Prompt) ->
        Pid ! {read, self()},
        receive
            {ok, Value} -> {ok, Value};
            done -> {error, nil}
        end
    end.

reader_loop([]) ->
    receive
        {read, From} -> From ! done
    end;
reader_loop([H | T]) ->
    receive
        {read, From} ->
            From ! {ok, H},
            reader_loop(T)
    end.
