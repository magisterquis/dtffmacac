#!/usr/bin/env perl
#
# httpchecker.t
# Make sure the httpchecker container works
# By J. Stuart McMurray
# Created 20241010
# Last Modified 20241020

use warnings;
use strict;
use feature 'signatures';
use Funcs;
use HTTP::Tiny;
use Test::More;

# This is terrible...
$Funcs::addr             = "127.0.0.1:4444";

# Get basic auth creds.
{
        my $tn = "Basic auth credentials";
        chomp($Funcs::basic_auth_creds = slurp(
                        "local/httpchecker_basicauth_creds",
        ));
        if ("" eq $Funcs::basic_auth_creds) {
                fail $tn;
        } else {
                like $Funcs::basic_auth_creds, qr/.+:.+/,
                        "Basic auth credentials";
        }
}

# testcmd runs $cmd and makes sure it returns $want
sub testcmd($cmd, $want) {
        # Run the command
        my $ok = 0;
        my $got = `$cmd 2>&1`;
        $? = 0;
        $! = 0;
        ok((sub {
                if ($? == -1) {
                        return diag "Failed to execute: $!\n";
                } elsif ($? & 127) {
                        return diag sprintf(
                                "Child died with signal %d, %s coredump\n",
                                ($? & 127),  ($? & 128) ? 'with' : 'without',
                        );
                }
                $ok = 1;
        })->(), "Command executed");

        # Work out if it's what we expect.
        unless (0 == $?) {
                fail("Command output");
                return;
        }
        chomp($got);
        is($got, $want, "Command output");
}

# cmd runs a subtest with the given name and passes the arguments to testcmd
sub cmd($name, $cmd, $want){
        subtest $name => \&testcmd, $cmd, $want;
}

# inject_is wraps get_is with shell injection.  This doesn't work with
# single-quotes.  If this a problem it can be changed to encode the command.
sub inject_is($cmd, $want, $name) {
        # Safen the command.
        $cmd = "'; $cmd #";
        $cmd =~ s/([^^A-Za-z0-9\-_.!~*'()])/ sprintf "%%%02x", ord $1 /eg;
        # Send it to the server.
        my $res = get "check?target=$cmd";
        # Extract and check just the command output.
        my $got = "";
        if ($res =~ /<h2>Output<\/h2>\n<pre>\n(.*)\n<\/pre>/s) {
                chomp($got = $1);
        }
        unless (is($got, $want, $name)) {
                diag "HTTP Response:\n$res";
                my $glen = length $got;
                diag "Output ($glen):\n$got";
        }
}


# Find the pid of the container, for /proc things.
chomp(my $pid = `pidof httpchecker`);
chomp($pid);
if ("" eq $pid) {
        die "Can't find httpchecer's pid" if "" eq $pid;
}
my $ppath = "/proc/$pid";



# Make sure our container started and is serving normal things.
cmd "Container started", "docker ps -q -f name=httpchecker | wc -l", "1" or
        die "Container isn't running";
get_is "", "404 page not found\n", 0, "400 for /";
get_is "check", <<'_eof', 0, "200 for /check";
<!doctype html>
<html>
<head>
<title>HTTP Checker</title>
</body>
<h1>HTTP Checker</h1>
<form action=/check>
	<label for="target">Target:</label>
	<input type="text" size="64" id="target" name="target"><br>
</form>
</body>
</html>
_eof
get_is("check?target=https://localhost:4444",
        <<'_eof', 0,"/check for localhost:4444");
<!doctype html>
<html>
<head>
<title>HTTP Checker</title>
</body>
<h1>HTTP Checker</h1>
<form action=/check>
	<label for="target">Target:</label>
	<input type="text" size="64" id="target" name="target"><br>
</form>
<h2>Target</h2>
<pre>
https://localhost:4444
</pre>

<h2>Command</h2>
<pre>
curl -skm3 &#39;https://localhost:4444&#39;
</pre>

<h2>Output</h2>
<pre>
404 page not found

</pre>

</body>
</html>
_eof

# Make sure creds are required.
get_is "check", "Unauthorized\n", 1, "Rejected creds";

# Make sure secrets made it into the container.
subtest "Secrets" => sub {
        # Make sure the secret file made it.
        is(
                slurp("$ppath/root/run/secrets/api_key"),
                slurp("./local/httpchecker_secret"),
                "Secret file",
        );

        # Make sure the environment variable is set.
        slurp("$ppath/environ") =~
                /(?:^|\0)INTERNAL_SERVICE_PASS=([^\0]+)(?:\0|$)/;
        chomp(my $isp = slurp(
                        "./local/httpchecker_internal_service_password",
        ));
        is($1, $isp, "Secret in environment");

        # Make sure the proxy credentials made it.
        chomp(my $proxy_creds = slurp("./local/httpchecker_basicauth_creds"));
        is(
                slurp("/proc/$pid/cmdline"),
                "/httpchecker\0-credentials\0$proxy_creds\0",
                "Secret in argv",
        );
};

# Make sure shell injection works.
inject_is(
        "id",
        "uid=0(root) gid=0(root) groups=0(root)",
        "Run a shell command",
);

# Make sure we can escape the container.
inject_is(
        <<~'_eof',
        set -e
        # Make a little script to run outside the container
        SCRIPT=/h4x_$$
        echo "#!/bin/sh" >$SCRIPT
        echo "exec >\$0.out 2>&1" >>$SCRIPT
        echo "cat </proc/1/comm" >>$SCRIPT
        chmod 0755 $SCRIPT
        # Use core_pattern to run it
        echo "|/proc/%P/root/$SCRIPT" >/proc/sys/kernel/core_pattern
        sh -c "kill -SEGV \$\$" >/dev/null 2>&1 || true
        # Get the output
        cat $SCRIPT.out
        # Clean up after ourselves
        rm $SCRIPT $SCRIPT.out
        echo core >/proc/sys/kernel/core_pattern
        _eof
        "systemd",
        "Container is escapable",
);

# Make sure core_pattern is reset.
is slurp("/proc/sys/kernel/core_pattern"), "core\n", "core_pattern is reset";

# Make sure there's no h4x files left lying about.
ok !<"/proc/*/root/h4x*">, "No spare h4x files left about";

# Make sure we actually deleted the disk files.
subtest "Removed disk files" => sub {
        # Read the disk file names
        my $pfile = "$ppath/root/proc/partitions";
        open(my $FH, "<", $pfile) or die "Cannot open $pfile: $!";
        my @dns = map {
                /(\S+)$/ &&
                "name" ne $1 ? "$ppath/root/dev/$1" : ()
        } <$FH>;
        isnt @dns, 0, "Found disk names" or return;

        # Make sure they're not there.
        for my $dn (@dns) {
                ok ! -e $dn, "Removed $dn";
        }
};

# Make sure the start script is gone.
ok ! -e "$ppath/root/httpcheckerstart.sh", "Startup script removed";

done_testing;
