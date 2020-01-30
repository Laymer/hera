%%%-------------------------------------------------------------------
%%% @author julien bastin
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. Jan 2020 12:45 PM
%%%-------------------------------------------------------------------
-module(hera_multicast).
-author("julien").

-behaviour(gen_server).

%% API
-export([start_link/0, stop/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

%%====================================================================
%% Macros
%%====================================================================

-define(SERVER, ?MODULE).
-define(MULTICAST_ADDR, {224,0,0,251}).
-define(MULTICAST_INTERFACE, {0,0,0,0}).

%%====================================================================
%% Records
%%====================================================================

-record(state, {
  controlling_process = {undefined, undefined}
}).
-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Spawns the server and registers the local name (unique)
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

stop(Pid) ->
  gen_server:call(Pid, stop).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
%% @doc Initializes the server
-spec(init(Args :: term()) ->
  {ok, State :: state()} | {ok, State :: state(), timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([]) ->
  {ok, #state{
    controlling_process = {undefined, undefined}
  }}.

%% @private
%% @doc Handling call messages
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: state()) ->
  {reply, Reply :: term(), NewState :: state()} |
  {reply, Reply :: term(), NewState :: state(), timeout() | hibernate} |
  {noreply, NewState :: state()} |
  {noreply, NewState :: state(), timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: state()} |
  {stop, Reason :: term(), NewState :: state()}).
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec(handle_cast(Request :: term(), State :: state()) ->
  {noreply, NewState :: state()} |
  {noreply, NewState :: state(), timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: state()}).
handle_cast(_Request, State) ->
  {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec(handle_info(Info :: timeout() | term(), State :: state()) ->
  {noreply, NewState :: state()} |
  {noreply, NewState :: state(), timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: state()}).
handle_info(_Info, State) ->
  ControllingProcess = case State#state.controlling_process of
   {undefined, undefined} ->
     Sock = open(),
     {Pid, Ref} = spawn_opt(?SERVER, receiver, [], [monitor]),
     ok = gen_udp:controlling_process(Sock, Pid),
     {Pid, Ref};
   {Pid, Ref} ->
     {Pid, Ref}
  end,

  {noreply, State#state{controlling_process = ControllingProcess}}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: state()) -> term()).
terminate(_Reason, _State) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
-spec(code_change(OldVsn :: term() | {down, term()}, State :: state(),
    Extra :: term()) ->
  {ok, NewState :: state()} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

open() ->
  {ok, Sock} = gen_udp:open(5353, [
    binary,
    {ip, {224,0,0,251}},
    {multicast_ttl, 3},
    {multicast_loop, false},
    {reuseaddr, true},
    {add_membership, {{224,0,0,251},{0,0,0,0}}},
    {active, true}
  ]),
  Sock.

stop({Sock, Pid}) ->
  gen_udp:close(Sock),
  Pid ! stop.

receiver() ->
  receive
    {udp, _Sock, IP, InPortNo, Packet} ->
      io:format("~n~nFrom: ~p~nPort: ~p~nData:~p~n", [IP,InPortNo,inet_dns:decode(Packet)]),
      receiver();
    stop -> true;
    AnythingElse -> io:format("RECEIVED: ~p~n", [AnythingElse]),
      receiver()
  end.