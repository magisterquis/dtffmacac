#!/usr/bin/env perl
#
# flags.t
# Make sure the flags are all in place
# By J. Stuart McMurray
# Created 20241015
# Last Modified 20241015

use warnings;
use strict;
use feature 'signatures';
use Test::More;

# slurp slurps a file
sub slurp($file) {
        local $/;
        my $FH;
        unless (open $FH, "<", $file) {
                diag "Could not open $file: $!";
                return;
        }
        my $b;
        unless (defined($b = <$FH>)) {
                diag "Failed to read $file: $!";
                return;
        }

        return $b;
}

# test_flag checks if flagf and localf have the same contents.
sub test_flag($flagf, $localf) {
        my ($flag, $local) = (slurp($flagf), slurp($localf));
        ok defined($flag),  "Have $flagf";
        ok defined($local), "Have $localf";
        is $flag, $local, "Flag contents correct";
}

# Get the HTTP Checker's pid
chomp(my $httpchecker_pid = `pidof httpchecker`);
isnt $httpchecker_pid, "", "HTTP Checker PID";

# %flags maps flags in local/ to the directory they should be in.
my %flags = (
        "httpchecker.flag" => "/proc/$httpchecker_pid/root/usr/lib",
        "escaped.flag"     => "/var/run",
);

# Make sure they're all there.
while (my ($fn, $dir) = each %flags) {
        subtest $fn => \&test_flag, "$dir/$fn", "local/$fn";
}

# Make sure someone has the deleted flag.
my $found_deleted = grep {/deleted\.flag \(deleted\)/} map {readlink // ()}
        <"/proc/*/fd/*">;
ok $found_deleted, "Deleted flag";

done_testing;
