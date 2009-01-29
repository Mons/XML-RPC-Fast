#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'XML::RPC::Fast' );
}

diag( "Testing XML::RPC::Fast $XML::RPC::Fast::VERSION, Perl $], $^X" );
