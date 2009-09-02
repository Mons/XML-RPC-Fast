#!/usr/bin/perl -w

use Test::More tests => 8;
use Test::NoWarnings;
use lib::abs '../lib';

BEGIN {
	use_ok( 'XML::RPC::Fast' );
	use_ok( 'XML::RPC::Enc' );
	use_ok( 'XML::RPC::Enc::LibXML' );
	use_ok( 'XML::RPC::UA' );
	use_ok( 'XML::RPC::UA::LWP' );
	SKIP: {
		eval { require AnyEvent::HTTP; } or skip "AnyEvent::HTTP missed, UA::AnyEvent will not work",1;
		use_ok( 'XML::RPC::UA::AnyEvent' );
		use_ok( 'XML::RPC::UA::AnyEventSync' );
	}
}

diag( "Testing XML::RPC::Fast $XML::RPC::Fast::VERSION, XML::LibXML $XML::LibXML::VERSION, Perl $], $^X" );
