#!/usr/bin/env perl
# Shared companions: scripts/ci/check-type-docs.pl
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use FindBin qw($Bin);
my $root = tempdir('type-docs.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $complete = 0;
END { if ($complete) { remove_tree($root); } else { print STDERR "Type docs fixture retained: $root\n"; } }
my $checker = "$Bin/check-type-docs.pl";
my $file = "$root/source.rs";
sub check {
    my ($source, $expected) = @_;
    open my $handle, '>', $file or die $!;
    print {$handle} $source;
    close $handle or die $!;
    my $status = system($^X, $checker, $file);
    ($status >> 8) == $expected or die "unexpected type-docs status: $status\n";
}
my $valid = <<'RUST';
mod nested {
    ///
    /// Current
    ///
    /// A current cross-module contract.
    ///

    #[derive(
        Debug,
    )]
    #[cfg_attr(any(), derive(Clone))]
    pub(crate) struct Current;
}
const RAW: &str = r###"
pub struct NotCode;
"###;
// pub enum NotCodeEither {}
/* outer /* nested */
pub trait NotCode {}
*/
RUST
check($valid, 0);
(my $missing = $valid) =~ s/    \/\/\/ A current cross-module contract[.]\n//;
check($missing, 1);
check("mod nested {\n    pub enum Missing {}\n}\n", 1);
(my $wrong_name = $valid) =~ s/\/\/\/ Current/\/\/\/ Another/;
check($wrong_name, 1);
check("pub fn helper() {}\nstruct Private;\n", 0);
check("const X: &str = r#\"unterminated", 255);
my $status = system($^X, $checker, "$root/missing");
$status != 0 or die "missing source selection accepted\n";
$status = system($^X, $checker, $root, $file);
$status != 0 or die "malformed input accepted through directory selection\n";
check($valid, 0);
$status = system($^X, $checker, $root, $file);
$status == 0 or die "overlapping valid source selections refused\n";
$complete = 1;
print "Section-style documentation selection, syntax and refusal fixtures passed\n";
