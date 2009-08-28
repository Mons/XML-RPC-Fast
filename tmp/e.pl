#!/usr/bin/env perl -w

use strict;
use lib::abs '../..';
use lib '/data/home/mons/work/trunk/modules/XML-Hash-LX/lib';
use XML::RPC::Fast;
use XML::RPC::Enc::LibXML;
use XML::RPC::Dec::LibXML;
use XML::Twig;
use R::Dump;
use Benchmark qw(:all);
use MIME::Base64 'encode_base64';

my $enc = XML::RPC::Enc::LibXML->new();
my $dec = XML::RPC::Dec::LibXML->new();
my $c = XML::RPC::Fast->new;
my $t = XML::Twig->new( pretty_print => 'indented' );

#use MIME::Base64 'encode_base64','decode_base64';

my @prm = (
	1, 0.1,
	a => { my => [ test => 1 ], -is => 1},
#	bless( do{\(my $o = '12345')}, 'estring' ),
#	bless( do{\(my $o = { inner => 1 })}, 'xval' ),
	sub {{ bool => '1' }},
	sub {{ base64 => encode_base64('test') } },
	sub {{ 'dateTime.iso8601' => '20090816T010203.04+0330' }},
#	bless( {}, 'zzz' ),
	sub {{ custom => 'cusval' }},
	#sub {[ { subs => 'subval' }, { -x => 1 } ]},
);
#print $t->parse(my $xml = $enc->encode( test => @prm ))->sprint;
#print $t->parse(my $xml = $enc->response( @prm ))->sprint;
print $t->parse(my $xml = $enc->fault( 111, 'err' ))->sprint;
print Dump + $dec->decode($xml);

__END__
use utf8;
use Encode;
use XML::LibXML;

	my $doc = XML::LibXML::Document->new('1.0','cp1251');
	my $root = XML::LibXML::Element->new('methodCall');
	$doc->setDocumentElement($root);
	my $n = XML::LibXML::Element->new('methodName');
	$n->appendText("тест");
	$root->appendChild($n);
	my $prms = XML::LibXML::Element->new('params');
	$root->appendChild($prms);
	
	print $doc->toString;
