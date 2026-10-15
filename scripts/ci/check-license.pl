#!/usr/bin/env perl
# Shared companions: licenses/MIT.txt licenses/Dragginz-ICP-Burn-1.0.txt licenses/prior-mit-notice.txt
use strict;
use warnings;
use FindBin;
use Getopt::Long qw(GetOptions);

my ($kind, $file, $prior_mit);
GetOptions('kind=s' => \$kind, 'file=s' => \$file, 'prior-mit' => \$prior_mit)
    && !@ARGV && defined($kind) && defined($file)
    && ($kind eq 'mit' || $kind eq 'dragginz')
    && (!$prior_mit || $kind eq 'dragginz')
    or die "usage: check-license.pl --kind mit|dragginz --file LICENSE [--prior-mit]\n";
my $root = "$FindBin::Bin/../../licenses";

sub read_file {
    my ($path) = @_;
    -f $path or die "not a license file: $path\n";
    open my $fh, '<', $path or die "cannot read $path: $!\n";
    local $/;
    my $text = <$fh>;
    close $fh or die "cannot close $path: $!\n";
    $text =~ s/\r\n/\n/g;
    return $text;
}

sub normalized {
    my ($text) = @_;
    $text =~ s/\s+/ /g;
    $text =~ s/^ | $//g;
    return $text;
}

sub check_text {
    my ($actual, $template) = @_;
    my ($prefix, $suffix) = split /\Q{{COPYRIGHT_NOTICES}}\E/, $template, -1;
    defined($suffix) or die "invalid canonical template\n";
    # Only the opening copyright block varies. Do not strip notices in clauses.
    $actual =~ /\A\Q$prefix\E((?:Copyright \(c\) [^\n]+\n)+)\n(.*)\z/s
        or die "missing or malformed copyright block in $file\n";
    my ($notices, $body) = ($1, $2);
    $notices !~ /\{\{|\}\}|[\x00-\x08\x0b-\x1f]/
        or die "invalid copyright notice in $file\n";
    normalized($body) eq normalized($suffix)
        or die "license terms differ from canonical $kind template: $file\n";
}

my $actual = read_file($file);
if ($prior_mit) {
    my $separator = read_file("$root/prior-mit-notice.txt");
    my @parts = split /\Q$separator\E/, $actual, -1;
    @parts == 2 or die "missing or repeated prior MIT notice: $file\n";
    check_text($parts[1], read_file("$root/MIT.txt"));
    $actual = $parts[0];
}
check_text($actual, read_file("$root/" . ($kind eq 'mit'
    ? 'MIT.txt' : 'Dragginz-ICP-Burn-1.0.txt')));
print "[OK] $file matches canonical $kind terms\n";
