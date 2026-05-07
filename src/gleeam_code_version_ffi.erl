-module(gleeam_code_version_ffi).
-export([get_version/0]).

get_version() ->
    application:load(gleeam_code),
    case application:get_key(gleeam_code, vsn) of
        {ok, Vsn} -> unicode:characters_to_binary(Vsn);
        undefined -> <<"unknown">>
    end.
