#!/usr/bin/env perl
#
# passwordstore.t
# Make sure the passwordstore container works
# By J. Stuart McMurray
# Created 20241019
# Last Modified 20241020

use warnings;
use strict;
use feature 'signatures';
use Funcs;
use HTTP::Tiny;
use Test::More;

# This is terrible...
$Funcs::addr             = "127.0.0.1:5555";
$Funcs::basic_auth_creds = ":4uthorized";

get_is "twitter", "l0ng_tw1tter_passw0rd\n", 0;
get_is "twitter", "Unauthorized\n",          1;
get_is "dummy",   "Got nothing\n",           0;
get_is "dummy",   "Unauthorized\n",          1;
get_is "xyzzy",   "Exception: -13 \n",       0;
get_is "xyzzy",   "Unauthorized\n",          1;

done_testing;
