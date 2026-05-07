-module(gleeam_code_submit_ffi).
-export([os_cmd/1, sleep/1]).

os_cmd(Cmd) ->
    Result = os:cmd(binary_to_list(Cmd)),
    unicode:characters_to_binary(Result).

sleep(Ms) ->
    timer:sleep(Ms),
    nil.
