-module(gleeam_code_list_test_ffi).
-export([collect_lines/1, random_suffix/0, remove_recursive/1]).

collect_lines(F) ->
    Ref = make_ref(),
    put(Ref, []),
    Print = fun(Line) -> put(Ref, [Line | get(Ref)]), nil end,
    F(Print),
    lists:reverse(get(Ref)).

random_suffix() ->
    integer_to_binary(erlang:unique_integer([positive])).

remove_recursive(Path) ->
    case rm_rf(binary_to_list(Path)) of
        ok -> {ok, nil};
        {error, _} -> {error, nil}
    end.

rm_rf(Dir) ->
    case filelib:is_dir(Dir) of
        true ->
            {ok, Entries} = file:list_dir(Dir),
            lists:foreach(fun(E) ->
                Full = filename:join(Dir, E),
                rm_rf(Full)
            end, Entries),
            file:del_dir(Dir);
        false ->
            file:delete(Dir)
    end.
