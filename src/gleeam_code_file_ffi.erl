-module(gleeam_code_file_ffi).
-export([write_file/2, ensure_dir/1, make_dir/1, delete_file/1, delete_dir/1, list_dir/1]).

%% Erlang file functions return ok | {error, Reason}.
%% Gleam Result expects {ok, Value} | {error, Reason}.
%% These wrappers convert ok -> {ok, nil} for Gleam compatibility.

write_file(Path, Contents) ->
    case file:write_file(Path, Contents) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

ensure_dir(Path) ->
    case filelib:ensure_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

make_dir(Path) ->
    case file:make_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

delete_file(Path) ->
    case file:delete(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

delete_dir(Path) ->
    case file:del_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

list_dir(Path) ->
    case file:list_dir(Path) of
        {ok, Entries} ->
            {ok, [unicode:characters_to_binary(E) || E <- Entries]};
        {error, Reason} -> {error, Reason}
    end.
