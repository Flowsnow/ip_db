#!/bin/bash
rebar compile skip_deps=true
cd ..
erl -name ip_db@127.0.0.1 -setcookie ip_db -pa ip_db/ebin -s ip_db -s observer
cd ip_db