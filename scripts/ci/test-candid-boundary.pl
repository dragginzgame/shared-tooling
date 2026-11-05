#!/usr/bin/env perl
# Shared companions: scripts/ci/check-candid-boundary.pl scripts/ci/prepare-script-fixture.sh
use strict;
use warnings;
use FindBin qw($Bin);
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use JSON::PP;
my $owner="$Bin/../../target/tmp";
make_path($owner);
my $root=tempdir('candid-boundary.XXXXXX',DIR=>$owner,CLEANUP=>0);
my $complete=0;
END { if ($complete) {remove_tree($root)} else {print STDERR "Candid fixture retained: $root\n"} }
make_path("$root/src");
my $json=JSON::PP->new->canonical;
sub write_file {open my $f,'>',$_[0] or die $!; print {$f} $_[1]; close $f or die $!;}
my $attempt=0;
sub check {
    my ($source,$allowances,$expected,$pattern,@selection)=@_;
    write_file("$root/src/lib.rs",$source);
    write_file("$root/policy.json",$json->encode({schema=>1,allowances=>$allowances}));
    my $log="$root/check-".++$attempt;
    my $pid=fork(); defined $pid or die $!;
    if (!$pid) {
        open STDOUT,'>',"$log.out" or die $!; open STDERR,'>',"$log.err" or die $!;
        exec $^X,"$Bin/check-candid-boundary.pl",$root,'policy.json',(@selection ? @selection : 'src'); die $!;
    }
    waitpid($pid,0)==$pid or die $!;
    my $status=$?;
    open my $f,'<',"$log.err" or die $!; local $/; my $error=<$f>;
    (($expected==0 && $status==0) || ($expected!=0 && $status!=0)) &&
        (!defined($pattern) || $error =~ $pattern) or die "case $attempt failed ($status): $error\n";
}
sub allow {
    my ($declaration,%extra)=@_;
    return {path=>'src/lib.rs',kind=>'external-protocol',protocol=>'IC HTTP gateway',reason=>'Exact gateway DTO, converted to owned response',declaration=>$declaration,%extra};
}
for my $source (
    '#[derive(CandidType)] struct App;',
    '#[cfg_attr(feature="external", derive(ic_platform::candid::contract::CandidType))] struct App;',
    'impl ic_platform::candid::contract::CandidType for App {}',
    'fn send<T: CandidType>(v:T) {}',
    'fn send<T>(v:T) where T: CandidType {}',
    'type Codec<T> = Box<dyn CandidType<Item=T>>;',
    'use x::{CandidType as External}; #[derive(External)] struct App;',
    'use x::CandidType as A; use x::A as B; impl B for App {}',
    'use x::CandidType as r#External; #[derive(r#External)] struct App;',
    'macro_rules! dto { () => { #[derive(CandidType)] struct App; } }',
    'quote! { #[derive(CandidType)] struct App; }',
) { check($source,[],1,qr/outside a reviewed/); }
check(<<'RUST',[],0,undef);
// #[derive(CandidType)]
/* nested /* CandidType */ impl CandidType for App {} */
const TEXT: &str = "impl CandidType for App {}";
const RAW: &str = r###"#[derive(CandidType)]"###;
use ic_platform::candid::contract::CandidType;
fn encode_one<T: serde::Serialize>(v:T) { ic_wire::native::encode(&v); }
fn decode_one() {}
RUST
my $declaration='#[derive(CandidType)] pub struct HttpResponse';
check("$declaration { status: u16 }",[allow($declaration)],0,undef);
check("$declaration { status: u16 } #[derive(CandidType)] struct Application;",[allow($declaration)],1,qr/outside a reviewed/);
check("// noise\n#[derive( /* comment */ CandidType)]\npub struct HttpResponse {status:u16}",[allow($declaration)],0,undef);
check('impl CandidType for HttpResponse {}',[allow('impl CandidType for HttpResponse')],0,undef);
check('fn decode<T: CandidType>(v:T) {}',[allow('fn decode<T: CandidType>')],0,undef);
my $callback='impl<Input: CandidType, Output: CandidType> QueryArchiveFn<Input, Output>';
check("$callback { fn new() {} }",[allow($callback,protocol=>'ICRC archive callback')],0,undef);
check("$callback where Input: Clone {}",[allow($callback)],1,qr/stale/);
check("$callback {} impl<T: CandidType> Other<T> {}",[allow($callback)],1,qr/outside a reviewed/);
check('impl<T> QueryArchiveFn<T> where T: CandidType {}',
    [allow('impl<T> QueryArchiveFn<T> where T: CandidType')],0,undef);
check('impl CandidType for HttpResponse {}',[allow('impl CandidType')],1,qr/stale/);
check("$callback {}",[allow('impl<Input: CandidType, Output: CandidType>')],1,qr/bounded declaration/);

check('use x::CandidType as External; #[derive(External)] struct Request;',[allow('#[derive(External)] struct Request')],0,undef);
check('#[derive(CandidType)] struct Comparison;',[allow('#[derive(CandidType)] struct Comparison',kind=>'codec-comparison',protocol=>'Wire/Candid benchmark',reason=>'Explicit competitor fixture')],0,undef);
for my $entry (
    allow('CandidType'), allow($declaration,path=>'src/*.rs'),
    allow($declaration,reason=>''), allow($declaration,kind=>'anything'),
    allow('mod adapter { #[derive(CandidType)] struct HttpResponse; }'),
    allow($declaration,extra=>'unrecognized'),
) {check("$declaration;",[$entry],1,undef);}
check('struct HttpResponse;',[allow($declaration)],1,qr/stale/);
check('struct HttpResponse;',[allow('struct HttpResponse')],1,qr/unused/);
check("$declaration; $declaration;",[allow($declaration)],1,qr/ambiguous/);
check("$declaration;",[allow($declaration),allow($declaration)],1,qr/overlapping/);
check('struct Fine;',[],1,qr/missing source/,'missing');
check('struct Fine;',[],1,qr/literal root-relative/,'../src');
symlink 'lib.rs',"$root/src/redirect.rs" or die $!;
check('struct Fine;',[],1,qr/symlink/);
unlink "$root/src/redirect.rs" or die $!;
check('/* unterminated',[],1,qr/unterminated/);
# Export closure must include the lexer; run the copied checker, not a live sibling.
make_path("$root/export");
system('bash',"$Bin/prepare-script-fixture.sh","$Bin/../..","$root/export",'scripts/ci/check-candid-boundary.pl')==0 or die 'export failed';
write_file("$root/src/lib.rs",'struct Fine;');
system($^X,"$root/export/scripts/ci/check-candid-boundary.pl",$root,'policy.json','src')==0 or die 'exported checker failed';
$complete=1;
print "Candid boundary: $attempt cases and exported lexer closure passed\n";
