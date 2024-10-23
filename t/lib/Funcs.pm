#!/usr/bin/env perl
#
# funcs.pl
# Handy testing function in a terrible module.
# By J. Stuart McMurray
# Created 20241020
# Last Modified 20241020

package Funcs;

use warnings;
use strict;
use feature 'signatures';

use Exporter 'import';
use Test::More;

# This is a terrible way to do this.
our ($addr, $basic_auth_creds);
our @EXPORT = qw/addr basic_auth_creds get_is get slurp/;

# get gets a path, the part after /.
sub get ($path, $no_auth = 0) {
        # Make sure we have the necessary variables.  In better code this would
        # probably be a method on a hash or something.
        die "\$addr not defined"             unless $addr;
        die "\$basic_auth_creds not defined" unless $basic_auth_creds;

        # Work out how to call this thing.
        my $url = $no_auth           ?
                "https://$addr/$path" :
                "https://$basic_auth_creds\@$addr/$path";

        # Actually make the request.
        return HTTP::Tiny->new( verify_SSL => 0,)->get($url)->{content};
}

# get_is gets a path, the part after /, and makes sure the response is $want.
sub get_is($path, $want, $no_auth = 0, $name = "") {
        # Work out the test's name and note the lack of auth if we're lacking
        # auth.
        if ("" eq $name) {
                $name = $path . ($no_auth ? " (no auth)" : "");
        }

        # See if it worked.
        is(get($path, $no_auth), $want, $name);
}

# slurp slurps a file
sub slurp($file) {
        local $/;
        my $FH;
        unless (open $FH, "<", $file) {
                diag "Could not open $file: $!";
                return "";
        }
        my $b;
        unless (defined($b = <$FH>)) {
                diag "Failed to read $file: $!";
                return "";
        }

        return $b;
}

1;
