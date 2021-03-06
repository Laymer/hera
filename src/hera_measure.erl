-module(hera_measure).
-behaviour(gen_server).
-export([start_link/1, stop/1]).
-export([init/1, handle_call/3, handle_cast/2,
handle_info/2, code_change/3, terminate/2]).
 
start_link(Delay) ->
    gen_server:start_link(?MODULE, Delay, []).
 
stop(Pid) ->
    gen_server:call(Pid, stop).


%%====================================================================
%% gen_server callbacks
%%====================================================================

init(Delay) ->
    Iter = 0,
    Id = {<<"measurements">>, state_orset},
    {ok, {Delay, Id, Iter}, Delay}. % {ok, state, timeout}

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(_Msg, _From, State) ->
    {noreply, State}.
        
handle_cast(_Msg, State) ->
    {noreply, State}.
        
handle_info(timeout, {Delay, Id, Iter}) ->
    Measure = pmod_maxsonar:get(),
    Name = node(),
    lasp:update(Id, {add, {Measure, Name}}, self()),
    {noreply, {Delay, Iter+1}, Delay}.
%% We cannot use handle_info below: if that ever happens,
%% we cancel the timeouts (Delay) and basically zombify
%% the entire process. It's better to crash in this case.
%% handle_info(_Msg, State) ->
%%    {noreply, State}.
        
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
        
terminate(_Reason, _State) -> ok.