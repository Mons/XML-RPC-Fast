#use strict;
use lib::abs '../lib';

use XML::RPC::Fast 'rpcfault';
use R::Dump;
use AnyEvent;
use Carp;

my $rpc = XML::RPC::Fast->new(
	'http://betty.userland.com/RPC2',
);
my $xml = $rpc->encoder->request( 'call' );
print $xml,"\n\n";
print $rpc->receive($xml,sub {
        #return rpcfault( 3, "Some error" );# if $error_condition
        $XML::RPC::Fast::faultCode = 4 and confess "Another error";# if $another_error_condition;
        warn Dump (\@params);

        return { call => $methodname, params => \@params };
});
__END__
#my $result = 
$xmlrpc->call( sub {
	warn Dump \@_;
	exit 0;
}, 'examples.getStateStruct', { state1 => 12, state2 => 28 } );
#print Dump $result;
AnyEvent->condvar->recv;