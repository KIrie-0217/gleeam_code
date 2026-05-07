-module(gleeam_code_io_ffi).
-export([get_line/1]).

get_line(Prompt) ->
    case io:get_line(Prompt) of
        eof -> {error, nil};
        {error, _} -> {error, nil};
        Data -> {ok, Data}
    end.
