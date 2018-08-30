%%%-------------------------------------------------------------------
%%% @author mac
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. 八月 2018 下午3:04
%%%-------------------------------------------------------------------
-module(ip_db_instance).

-behaviour(gen_server).
-include("ip_db.hrl").

%% API
-export([ip_region/1]).
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
-spec ip_region(Address :: inet:ip_address()) -> {ok, #ip_db_region{}}.
ip_region(Address) ->
  [{_, GbTree}] = ets:lookup(?SERVER, element(1, Address)),
  lookup(GbTree, Address).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([]) ->
  ets:new(?SERVER, [named_table]),
  gen_server:cast(self(), init),
  {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(init, State) ->
  {ok, Data} = file:read_file(filename:join(code:lib_dir(ip_db, priv), "ip_db")),
  ok = parse_data(Data),
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec lookup(GbTree, Address) -> Result when
  GbTree :: {Address, GbTree, GbTree} | #ip_db_region{},
  Address :: inet:ip_address(),
  Result :: {ok, #ip_db_region{}}.
lookup(Value = #ip_db_region{}, _Address) ->
  {ok, Value};
lookup({Address0, LeftTree, _}, Address) when Address =< Address0 ->
  lookup(LeftTree, Address);
lookup({_, _, RightTree}, Address) ->
  lookup(RightTree, Address).

-spec parse_data(Data :: binary()) -> ok.
parse_data(Data) ->
  <<DataPosPlus1024:32, _/binary>> = Data,
  DataPos = DataPosPlus1024 - 1024,
  IpIndex = binary:part(Data, 4 + 1024, DataPos - 1024 - 4),
  IpData = binary:part(Data, DataPos, size(Data) - DataPos),
  {ok, CountryIsoCodeTid} = get_country_iso_code_tid(),
  {ok, ProvinceIsoCodeTid} = get_province_iso_code(),
  Result = parse_data(IpIndex, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid),
  ets:delete(CountryIsoCodeTid),
  ets:delete(ProvinceIsoCodeTid),
  Result.

-spec parse_data(IpIndex :: binary(), IpData :: binary(), CountryIsoCodeTid :: ets:tid(), ProvinceIsoCodeTid :: ets:tid()) -> ok.
parse_data(IpIndex, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid) ->
  parse_data(IpIndex, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid, []).

-spec parse_data(IpIndex, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid, Ret) -> ok when
  IpIndex :: binary(),
  IpData :: binary(),
  CountryIsoCodeTid :: ets:tid(),
  ProvinceIsoCodeTid :: ets:tid(),
  Ret :: list({Ip, Value}),
  Ip :: inet:ip_address(),
  Value :: binary().
parse_data(<<>>, _IpData, _CountryIsoCodeTid, _ProvinceIsoCodeTid, Ret) ->
  DeepList = lists:foldl(
    fun(Elem, AccIn) ->
      {A, _, _, _} = element(1, Elem),
      case AccIn of
        [H | T] ->
          case H of
            [{{A, _, _, _}, _} | _] ->
              [[Elem | H] | T];
            _ ->
              [[Elem] | AccIn]
          end;
        _ ->
          [[Elem]]
      end
    end,
    [],
    Ret
  ),
  parse_dat1(DeepList);
parse_data(IpIndex = <<A, B, C, D, Pos:24/little, Len, _/binary>>, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid, Ret) ->
  Bin = binary:part(IpData, Pos, min(size(IpData) - Pos, Len)),
  {Country, Province} = case binary:split(Bin, <<9>>) of
                       [Country0] ->
                         {Country0, Country0};
                       [Country0, Part1] ->
                         case binary:split(Part1, <<9>>) of
                           [Province0, _] ->
                             {Country0, Province0};
                           [Province0] ->
                             {Country0, Province0}
                         end
                     end,
  Value = case ets:lookup(CountryIsoCodeTid, Country) of
            [{Country, CountryIsoCode}] ->
              case ets:lookup(ProvinceIsoCodeTid, Province) of
                [{Province, ProvinceIsoCode}] ->
                  #ip_db_region{
                    country_iso_code = CountryIsoCode,
                    country = Country,
                    province_iso_code = ProvinceIsoCode,
                    province = Province
                  };
                _ ->
                  #ip_db_region{
                    country_iso_code = CountryIsoCode,
                    country = Country,
                    province = Province
                  }
              end;
            _ ->
              #ip_db_region{}
          end,
  Rest = binary:part(IpIndex, 8, size(IpIndex) - 8),
  Ip = {A, B, C, D},
  case Ret of
    [{{A, _, _, _}, Value0} | T] when Value =:= Value0 ->
      parse_data(Rest, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid, [{Ip, Value} | T]);
    _ ->
      parse_data(Rest, IpData, CountryIsoCodeTid, ProvinceIsoCodeTid, [{Ip, Value} | Ret])
  end.

-spec parse_dat1(Deeplist) -> ok when
  Deeplist :: list(Proplist),
  Proplist :: list({Ip, Country, Region}),
  Ip :: inet:ip_address(),
  Country :: binary(),
  Region :: binary().
parse_dat1(Deeplist) ->
  lists:foreach(
    fun
      ([]) ->
        ok;
      (Proplist) ->
        {{Key, _, _, _}, _} = hd(Proplist),
        GbTree = generate_gb_tree(Proplist),
        ets:insert(?MODULE, {Key, GbTree})
    end,
    Deeplist
  ).

-spec generate_gb_tree(Proplist) -> GbTree when
  Proplist :: proplists:proplist(),
  GbTree :: {Ip, GbTree, GbTree} |  #ip_db_region{},
  Ip :: inet:ip_address().
generate_gb_tree([{_, Value}]) ->
  Value;
generate_gb_tree(Proplist) ->
  {List1, List2} = lists:split(length(Proplist) div 2, Proplist),
  {Ip, _} = lists:last(List1),
  {Ip, generate_gb_tree(List1), generate_gb_tree(List2)}.

-spec get_country_iso_code_tid() -> {ok, Tid :: ets:tid()}.
get_country_iso_code_tid() ->
  Tid = ets:new(undefined, []),
  {ok, IoDevice} = file:open(filename:join(code:lib_dir(ip_db, priv), "country.csv"), [read, binary]),
  ok = get_country_iso_code_tid1(IoDevice, Tid),
  file:close(IoDevice),
  {ok, Tid}.

-spec get_country_iso_code_tid1(IoDevice :: file:io_device(), Tid :: ets:tid()) -> ok.
get_country_iso_code_tid1(IoDevice, Tid) ->
  case file:read_line(IoDevice) of
    {ok, Line} ->
      case binary:split(Line, <<",">>, [global]) of
        [CountryIsoCode, _, Country | _] ->
          ets:insert(Tid, {Country, CountryIsoCode});
        _ ->
          ok
      end,
      get_country_iso_code_tid1(IoDevice, Tid);
    eof ->
      ok
  end.

get_province_iso_code() ->
  Tid = ets:new(undefined, []),
  {ok, IoDevice} = file:open(filename:join(code:lib_dir(ip_db, priv), "province.csv"), [read, binary]),
  ok = get_province_iso_code1(IoDevice, Tid),
  {ok, Tid}.

-spec get_province_iso_code1(IoDevice :: file:io_device(), Tid :: ets:tid()) -> ok.
get_province_iso_code1(IoDevice, Tid) ->
  case file:read_line(IoDevice) of
    {ok, LineData} ->
      case binary:split(LineData, [<<",">>, <<"\n">>], [global]) of
        [PrivinceIsoCode, Province, _] ->
          ets:insert(Tid, {Province, PrivinceIsoCode});
        _ ->
          ok
      end,
      get_province_iso_code1(IoDevice, Tid);
    eof ->
      ok
  end.