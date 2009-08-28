#!/usr/bin/perl -w

use Test::More tests => 6;
use Test::NoWarnings;
use lib::abs '../lib';

BEGIN {
	use_ok( 'XML::RPC::Fast' );
	use_ok( 'XML::RPC::Enc' );
	use_ok( 'XML::RPC::Enc::LibXML' );
	use_ok( 'XML::RPC::UA' );
	use_ok( 'XML::RPC::UA::LWP' );
}

diag( "Testing XML::RPC::Fast $XML::RPC::Fast::VERSION, Perl $], $^X" );
