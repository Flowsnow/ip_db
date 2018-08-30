-ifndef(IP_DB_HRL).
-define(IP_DB_HRL, 1).

-record(ip_db_region, {
  country_iso_code = <<"other">> :: binary(),
  country = <<"other">> :: binary(),
  province_iso_code = <<"other">> :: binary(),
  province = <<"other">> :: binary()
}).
-endif.