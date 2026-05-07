-module(gleeam_code_test_cmd_ffi).
-export([list_directory/1]).

list_directory(Path) ->
    case file:list_dir(Path) of
        {ok, Entries} ->
            Binaries = [unicode:characters_to_binary(E) || E <- Entries],
            {ok, Binaries};
        {error, _} ->
            {error, nil}
    end.
