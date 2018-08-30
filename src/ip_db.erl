-module(ip_db).
-include("ip_db.hrl").

%% API

-export([start/0, stop/0]).
-export([ip_region/1]).

-spec ip_region(Ip :: string() | inet:ip_address()) -> {ok, #ip_db_region{}}.
ip_region(Ip) when is_list(Ip) ->
  {ok, Address} = inet_parse:address(Ip),
  ip_region(Address);
ip_region({0, 0, 0, 0}) ->
  {ok, #ip_db_region{
    country_iso_code = <<"CN">>,
    country = <<228,184,173,229,155,189>>
  }};
ip_region(Address) ->
  ip_db_instance:ip_region(Address).

start() ->
  application:start(?MODULE).

stop() ->
  application:stop(?MODULE).