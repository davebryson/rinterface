%%
%% Simple add server
%%
-module(math_server).
-export([start/0,add/2]).

start() ->
    register(?MODULE,spawn(fun() -> loop() end)).

add(X,Y) ->
    ?MODULE ! {self(),add,X,Y},
    receive
	{?MODULE,Response} -> Response
    end.

loop() ->
    receive
	{From,add,X,Y} ->
	    error_logger:info_msg("Got the request, and doing the add...~n"),
	    Sum = X+Y,
	    From ! {?MODULE,Sum},
	    loop();
	Any ->
	    error_logger:info_msg("Got a crazy msg: ~p~n",[Any]),
	    loop()
    end.
