#!/usr/bin/perl -w

use ex::lib '../lib';
use XML::RPC::Fast;
use Test::More;

my $ver = '0.8';
eval "use XML::RPC $ver";
plan skip_all => "XML::RPC $ver required for testing compatibility" if $@;
plan tests => 2;

my $r = XML::RPC->new();
my $hash = [ { name => 'rec', entries => { name => 'ent', fields => [] } } ];
my $xml = $r->create_call_xml(test => $hash);
my $hml = $r->{tpp}->parse($xml);
my @in = $r->unparse_call($hml);
my $f = XML::RPC::Fast->new();
my $f_hml = $f->parse_xml($xml);
is_deeply($hml,$f_hml, 'hash struct');
my @f_in  = $f->unparse_call($hml);
is_deeply(\@in,\@f_in, 'args struct');

