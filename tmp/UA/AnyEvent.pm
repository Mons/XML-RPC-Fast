package XML::RPC::UA::AnyEvent;

use strict;
use HTTP::Response;
use HTTP::Headers;
use AnyEvent::HTTP 'http_request';
use Carp;

use XML::RPC::Fast ();
our $VERSION = $XML::RPC::Fast::VERSION;

sub async { 1 }

sub new {
	my $pkg = shift;
	my %args = @_;
	return bless \(do {my $o = $args{ua} || 'XML-RPC-Fast/'.$XML::RPC::Fast::VERSION }),$pkg;
}

sub call {
	my $self = shift;
	my ($method, $url) = splice @_,0,2;
	my %args = @_;
	$args{cb} or croak "cb required for useragent @{[%args]}";
	#warn "call";
	http_request
		$method => $url,
		headers => {
			'Content-Type'   => 'text/xml',
			'User-Agent'     => $$self,
			do { use bytes; ( 'Content-Length' => length($args{body}) ) },
			%{$args{headers} || {}},
		},
		body => $args{body},
		cb => sub {
			$args{cb}( HTTP::Response->new(
				$_[1]{Status},
				$_[1]{Reason},
				HTTP::Headers->new(%{$_[1]}),
				$_[0],
			) );
		},
	;
	return;
}

1;
