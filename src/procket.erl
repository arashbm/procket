%% Copyright (c) 2010, Michael Santos <michael.santos@gmail.com>
%% All rights reserved.
%% 
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%% 
%% Redistributions of source code must retain the above copyright
%% notice, this list of conditions and the following disclaimer.
%% 
%% Redistributions in binary form must reproduce the above copyright
%% notice, this list of conditions and the following disclaimer in the
%% documentation and/or other materials provided with the distribution.
%% 
%% Neither the name of the author nor the names of its contributors
%% may be used to endorse or promote products derived from this software
%% without specific prior written permission.
%% 
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
-module(procket).
-include("procket.hrl").

-export([
        init/0,open/1,open/2,
        socket/3, listen/2,connect/2,
        accept/1,accept/2,
        fdopen/1,fdrecv/1,close/1,close/2,
        recvfrom/2,sendto/4,bind/2,
        ioctl/3,setsockopt/4
    ]).
-export([make_args/2,progname/0]).

-on_load(on_load/0).


init() ->
    on_load().

on_load() ->
    erlang:load_nif(progname(), []).


close(_) ->
    erlang:error(not_implemented).

fdrecv(_) ->
    erlang:error(not_implemented).

close(_,_) ->
    erlang:error(not_implemented).

accept(Socket) ->
    accept(Socket, <<>>).
accept(_,_) ->
    erlang:error(not_implemented).

bind(_,_) ->
    erlang:error(not_implemented).

connect(_,_) ->
    erlang:error(not_implemented).

listen(_,_) ->
    erlang:error(not_implemented).

recvfrom(_,_) ->
    erlang:error(not_implemented).

socket(_,_,_) ->
    erlang:error(not_implemented).

ioctl(_,_,_) ->
    erlang:error(not_implemented).

sendto(_,_,_,_) ->
    erlang:error(not_implemented).

setsockopt(_,_,_,_) ->
    erlang:error(not_implemented).


open(Port) ->
    open(Port, []).
open(Port, Options) when is_integer(Port), is_list(Options) ->
    Opt = case proplists:get_value(pipe, Options) of
        undefined ->
            Tmp = mktmp:dirname(),
            ok = mktmp:make_dir(Tmp),
            Path = Tmp ++ "/sock",
            [{pipe, Path}, {tmpdir, Tmp}] ++ Options;
        _ ->
            [{tmpdir, false}] ++ Options
    end,
    open1(Port, Opt).

open1(Port, Options) ->
    Pipe = proplists:get_value(pipe, Options),
    {ok, Sockfd} = fdopen(Pipe),
    Cmd = make_args(Port, Options),
    case os:cmd(Cmd) of
        [] ->
            FD = fdget(Sockfd),
            cleanup(Sockfd, Pipe, Options),
            FD;
        Error ->
            cleanup(Sockfd, Pipe, Options),
            {error, {procket_cmd, Error}}
    end.

cleanup(Sockfd, Pipe, Options) ->
    close(Sockfd, Pipe),
    case proplists:get_value(tmpdir, Options) of
        false ->
            ok;
        Path ->
            mktmp:close(Path)
    end.

fdopen(Path) when is_list(Path) ->
    fdopen(list_to_binary(Path));
fdopen(Path) when is_binary(Path), byte_size(Path) < ?UNIX_PATH_MAX ->
    {ok, Socket} = socket(?PF_LOCAL, ?SOCK_STREAM, 0),
    Sun = <<?PF_LOCAL:16/native, Path/binary, 0:((?UNIX_PATH_MAX-byte_size(Path))*8)>>,
    ok = bind(Socket, Sun),
    ok = listen(Socket, ?BACKLOG),
    {ok, Socket}.

fdget(Socket) ->
    {ok, S} = accept(Socket),
    fdrecv(S).

make_args(Port, Options) ->
    Bind = " " ++ case proplists:lookup(ip, Options) of
        none ->
            integer_to_list(Port);
        IP ->
            get_switch(IP) ++ ":" ++ integer_to_list(Port)
    end,
    proplists:get_value(progname, Options, "sudo " ++ progname()) ++ " " ++
    string:join([ get_switch(proplists:lookup(Arg, Options)) || Arg <- [
                pipe,
                protocol,
                family,
                type,
                interface
            ], proplists:lookup(Arg, Options) /= none ],
        " ") ++ Bind.

get_switch({pipe, Arg})         -> "-p " ++ Arg;

get_switch({protocol, raw})     -> "-P 0";
get_switch({protocol, icmp})    -> "-P 1";
get_switch({protocol, tcp})     -> "-P 6";
get_switch({protocol, udp})     -> "-P 17";
get_switch({protocol, Proto}) when is_integer(Proto) -> "-P " ++ integer_to_list(Proto);

get_switch({type, stream})      -> "-T 1";
get_switch({type, dgram})       -> "-T 2";
get_switch({type, raw})         -> "-T 3";
get_switch({type, Type}) when is_integer(Type) -> "-T " ++ integer_to_list(Type);

get_switch({family, unspec})    -> "-F 0";
get_switch({family, inet})      -> "-F 2";
get_switch({family, packet})    -> "-F 17";
get_switch({family, Family}) when is_integer(Family) -> "-F " ++ integer_to_list(Family);

get_switch({ip, Arg}) when is_tuple(Arg) -> inet_parse:ntoa(Arg);
get_switch({ip, Arg}) when is_list(Arg) -> Arg;

get_switch({interface, Name}) when is_list(Name) ->
    % An interface name is expected to consist of a reasonable
    % subset of all charactes, use a whitelist and extend it if needed
    SName = [C || C <- Name, ((C >= $a) and (C =< $z)) or ((C >= $A) and (C =< $Z))
                          or ((C >= $0) and (C =< $9)) or (C == $.)],
    "-I " ++ SName.

progname() ->
    filename:join([
        filename:dirname(code:which(?MODULE)),
        "..",
        "priv",
        ?MODULE
    ]).


