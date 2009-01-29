#!/usr/bin/perl -w

use Test::More tests => 1;
use ex::lib '../lib';

BEGIN {
	use_ok( 'XML::RPC::Fast' );
}

diag( "Testing XML::RPC::Fast $XML::RPC::Fast::VERSION, Perl $], $^X" );
