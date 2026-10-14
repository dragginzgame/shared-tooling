#!/usr/bin/env bash
# Shared companions: scripts/ci/check-pipe-jobserver.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
root="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/pipe-jobserver.XXXXXX")"
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Failed jobserver fixture retained"' EXIT
export JOBSERVER_PROBE="$root/scripts/ci/check-pipe-jobserver.pl"
# Exercise inherited descriptors with real Make; serial and stale flags refuse.
# shellcheck disable=SC2016 # Preserve Make variable syntax.
printf 'check:\n\t+perl "$(JOBSERVER_PROBE)"\n' > "$fixture/Makefile"
parallel=(-j2)
if make --help | grep -q -- --jobserver-style; then parallel+=(--jobserver-style=pipe); fi
make "${parallel[@]}" -C "$fixture" check > "$fixture/parallel.log" 2>&1
if make -C "$fixture" check > "$fixture/serial.log" 2>&1; then exit 1; fi
for flags in '' '--jobserver-auth=88,89' '--jobserver-fds=88,89' '--jobserver-auth=fifo:/absent'; do
    if MAKEFLAGS="$flags" perl "$JOBSERVER_PROBE" > "$fixture/invalid.log" 2>&1; then exit 1; fi
done
# Construct actual pipes to qualify direction, token custody and the old fds form.
perl -MFcntl=F_GETFD,F_SETFD -MIO::Handle -e '
    pipe(my $r, my $w) or die $!;
    fcntl($_, F_SETFD, 0) or die $! for ($r, $w);
    $w->autoflush(1);
    print {$w} "token" or die $!;
    for my $kind (qw(auth fds)) {
        $ENV{MAKEFLAGS} = "--jobserver-$kind=" . fileno($r) . "," . fileno($w);
        system("perl", $ARGV[0]) == 0 or die "valid pipe refused\n";
    }
    $ENV{MAKEFLAGS} = "--jobserver-auth=" . fileno($w) . "," . fileno($r);
    system("perl", $ARGV[0]) != 0 or die "reversed pipe admitted\n";
    $ENV{MAKEFLAGS} = "--jobserver-auth=" . fileno($r) . "," . fileno($r);
    system("perl", $ARGV[0]) != 0 or die "duplicate pipe admitted\n";
    close $w or die $!;
    my $bytes = do { local $/; <$r> };
    $bytes eq "token" or die "probe changed token stream\n";
    open my $file, "<", $ARGV[0] or die $!;
    fcntl($file, F_SETFD, 0) or die $!;
    $ENV{MAKEFLAGS} = "--jobserver-auth=" . fileno($file) . ",1";
    system("perl", $ARGV[0]) != 0 or die "regular file admitted\n";
' "$JOBSERVER_PROBE" > "$fixture/descriptors.log" 2>&1
fixture_complete=true
echo 'pipe jobserver observation passed (no token IO)'
