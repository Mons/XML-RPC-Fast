# XML::RPC::Fast
#
# Copyright (c) 2008 Mons Anderson <mons@cpan.org>, all rights reserved
# Based on XML::RPC v0.8 (c) 2007-2008 Niek Albers
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
package XML::RPC::Fast::Old;

=head1 NAME

XML::RPC::Fast - Faster implementation for an XML-RPC client and server (based on XML::RPC)

=head1 VERSION

Version 0.3

=head1 SYNOPSIS

Generic usage

	use XML::RPC::Fast;
	
	my $server = XML::RPC::Fast->new( undef, [ %PARAMS ] );
	my $client = XML::RPC::Fast->new( $uri, [ %PARAMS ] );

Create a simple XML-RPC service:

	use XML::RPC::Fast;
	
	my $rpc = XML::RPC::Fast->new(
		undef, # the url is not required by server
		external_encoding => 'utf8',
		internal_encoding => 'koi8r', # any encoding, accepted by Encode
	);
	my $xml = do { local $/; <STDIN> };
	length($xml) == $ENV{CONTENT_LENGTH} or warn "Content-Length differs from actually received";
	
	print "Content-type: text/xml; charset: utf-8\n\n";
	print $rpc->receive( $xml, sub {
		my ( $methodname, @params ) = @_;
		return { you_called => $methodname, with_params => \@params };
	} );

Make a call to an XML-RPC service:

	use XML::RPC::Fast;
	
	my $rpc = XML::RPC::Fast->new(
		'http://your.hostname/rpc/url'
		internal_encoding => 'koi8r', # any encoding, accepted by Encode
	);
	my $result = $rpc->call( 'examples.getStateStruct', { state1 => 12, state2 => 28 } );

=head1 DESCRIPTION

XML::RPC::Fast doing the same as XML::RPC does, but uses XML::Parser to parse xml,
so it is faster on big data structures.
The supported options is almost the same, as XML::RPC have, so refer to its documentation.
There are also have been made beautifications in error handling. Errors in this module is more verbose
and self-descriptive. Below are list of options, that are differs from XML::RPC and XML::TreePP;

=head1 SPECIFIC OPTIONS

=head2 internal_encoding

Specify the encoding you are using in your code. By default option is undef, which means flagged utf-8
For translations is used Encode, so the list of accepted encodings fully derived from it.

=head2 external_encoding

Specify the encoding, used inside XML container. By default it's utf-8; Uses Encode for translations.

=head2 no_xml_parser

Specific option. If set, Use XML::TreePP for XML parsing, instead of XML::Parser in some place.
But why then you need this module? XML::RPC does the same.

=head1 BUGS

Bugs reports and testcases are welcome.

See L<http://rt.cpan.org> to report and view bugs.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2008-2009 Mons Anderson.
Based on C<XML::RPC> v0.8 (c) 2007-2008 Niek Albers

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Mons Anderson, C<< <mons@cpan.org> >>

=cut

use strict;
BEGIN {
	if( $] >= 5.007003 ) {
		require Encode;
	} else {
		require Text::Iconv;
	}
}
use Scalar::Util ();

use XML::Parser;
use LWP::UserAgent;
use Time::HiRes qw(time);
use Carp qw(carp);

BEGIN {
	eval {
		require Sub::Name;
		Sub::Name->import('subname');
	1 } or do { *subname = sub { $_[1] } }
}

#use Data::Dumper;
sub DEBUG_TIMES ()    { 0 }
sub DEBUG_ENCODING () { 0 }

our $VERSION   = 0.3; # Based on XML::RPC 0.8
our $faultCode = 0;
our $FAULTY    = 1;

our $XML_ENCODING      = 'UTF-8';
our $INTERNAL_ENCODING = 'UTF-8';
our $USER_AGENT        = 'XML-RPC-Fast/'.$VERSION.' ';
our $ATTR_PREFIX       = '-';
our $TEXT_NODE_KEY     = '#text';

sub croak {
	no strict 'refs';
	shift;# if ( ref $_[0] || $_[0] ) =~ __PACKAGE__;
	my $msg = sprintf shift, map { defined $_ ? length $_ ? $_ : '<empty>' : '<undef>' } @_;
	( 'Carp::' . ($FAULTY ? 'croak' : 'carp') )->( $msg );
}

sub new {
	my $package = shift;
	my $url  = shift;
	local $SIG{__WARN__} = sub { local $_ = shift; s{\n$}{};carp $_ };
	my $self = { @_ };
	$self->{url} = $url;
	bless $self, $package;
	return $self;
}

sub local_call_send {
	my $self = shift;
	my ( $methodname, @params ) = @_;
	return $self->create_call_xml( $methodname, @params );
}

sub local_call_receive {
	my $self = shift;
	my $xml = shift;
	my $tree = $self->parse_xml( \$xml );
	$self->{xml_in} = $xml;
	my @data = $self->unparse_response($tree);
	$self->croak( "Remote Error: ".$data[0]{faultString} ) if ref $data[0] eq 'HASH' and exists $data[0]{faultString} and exists $data[0]{faultCode};
	return @data == 1 ? $data[0] : @data;
}

sub call {
	my $self = shift;
	my ( $methodname, @params ) = @_;
    @$self{qw(xml_in xml_out)} = (undef)x2;

	$self->croak('no url: %s',$self->{url}) unless $self->{url};

	$faultCode = 0;
	my $body = $self->create_call_xml( $methodname, @params );

	$self->{xml_out} = $body;

	my $url    = $self->{url} or return $self->die( 'Invalid URL' );
	my $header = {
		'Content-Type'   => 'text/xml',
		'User-Agent'     => $USER_AGENT,
		'Content-Length' => length($body)
	};
	$self->{useragent} ||= do {
		my $ua = LWP::UserAgent->new( exists $self->{lwp_param} ?  %{$self->{lwp_param}} : requests_redirectable => ['POST'] );
		$ua->timeout( exists $self->{timeout} ? $self->{timeout} : 10);
		$ua->env_proxy();
		$ua->agent( $self->{__user_agent} ) if defined $self->{__user_agent};
		$ua;
	};

	my $req = HTTP::Request->new( POST => $url );
	$req->header( 'Content-Type'   => 'text/xml' );
	$req->header( 'User-Agent'     => $USER_AGENT );
	$req->header( 'Content-Length' => length($body) );
	$req->content($body) if defined $body;
	my $start = time;
	my $res = $self->{useragent}->request($req);
	warn sprintf "http call lasts %0.3fs",time - $start if DEBUG_TIMES;
	( my $status = $res->status_line )=~ s/:?\s*$//s;
	$res->code == 200 or $self->croak( "Call to $self->{url}#$methodname error %s: %s",$res->code,$status );
	my $text = $res->content();
    length($text) and $text =~ /^\s*<\?xml/s or $self->croak( "Call to $self->{url}#$methodname error: response is not an XML: \"$text\"" );
	$self->{xml_in} = $text;
	my $tree = $self->parse_xml( \$text );


	my @data = $self->unparse_response($tree);
	$self->croak( "Remote Error: ".$data[0]{faultString} ) if ref $data[0] eq 'HASH' and exists $data[0]{faultString} and exists $data[0]{faultCode};
	return @data == 1 ? $data[0] : @data;
}

sub receive {
	my $self   = shift;
	my $result = eval {
		my $xml_in = shift or $self->croak('no xml');
		$self->{xml_in} = $xml_in;
		my $handler = shift or $self->croak('no handler');
		my $hash = $self->parse_xml($xml_in);
		#local $Data::Dumper::Indent = 1;
		#warn Dumper ($hash);
		my ( $methodname, @params ) = $self->unparse_call($hash);
		$self->create_response_xml( $handler->( $methodname, @params ) );
	};

	$result = $self->create_fault_xml($@) if ($@);
	$self->{xml_out} = $result;
	return $result;

}

sub create_fault_xml {
	my $self  = shift;
	my $error = shift;
	chomp($error);
	return $self->compose_xml( { methodResponse => { fault => $self->parse( { faultString => $error, faultCode => int($faultCode) } ) } } );
}

sub create_call_xml {
	my $self = shift;
	my ( $methodname, @params ) = @_;

	return $self->compose_xml(
		sub {+{
			methodCall => {
				methodName => $methodname,
				params     => { param => [ map { $self->parse($_) } @params ] }
			}
		}}
	);
}

sub create_response_xml {
	my $self   = shift;
	my @params = @_;

	return $self->compose_xml( { methodResponse => { params => { param => [ map { $self->parse($_) } @params ] } } } );
}

sub parse {
	my $self = shift;
	my $p    = shift;
	my $result;

	if ( ref($p) eq 'HASH' ) {
		$result = $self->parse_struct($p);
	}
	elsif ( ref($p) eq 'ARRAY' ) {
		$result = $self->parse_array($p);
	}
	elsif ( ref($p) eq 'CODE' ) {
		$result = $p->();
	}
	else {
		$result = $self->parse_scalar($p);
	}

	return { value => $result };
}

sub parse_scalar {
	my $self   = shift;
	my $scalar = shift;
	local $^W = undef;

	if (   ( $scalar =~ m/^[\-+]?\d+$/ )
		&& ( abs($scalar) <= ( 0xffffffff >> 1 ) ) )
	{
		return { i4 => $scalar };
	}
	elsif ( $scalar =~ m/^[\-+]?\d+\.\d+$/ ) {
		return { double => $scalar };
	}
#	elsif( utf8::is_utf8($scalar) ) {
#		return { string => $scalar };
#	}
	else {
		return { string => \$scalar };
	}
}

sub parse_struct {
	my $self = shift;
	my $hash = shift;
	return {
		struct => {
			member => [
				map { +{
					( $_ eq $self->{text_node_key} ? () : ( name => $_ ) ),
					%{ $self->parse( $hash->{$_} ) }
				} } keys %$hash
			]
		}
	};
}

sub parse_array {
	my $self  = shift;
	my $array = shift;

	return { array => { data => { value => [ map { $self->parse($_)->{value} } $self->list($array) ] } } };
}

sub unparse_response {
	my $self = shift;
	my $hash = shift;

	my $response = $hash->{methodResponse} or $self->croak('no data in response');

	if ( $response->{fault} ) {
		return $self->unparse_value( $response->{fault}->{value} );
	}
	else {
		return map { $self->unparse_value( $_->{value} ) } $self->list( eval{ $response->{params}->{param} } );
	}
}

sub unparse_call {
	my $self = shift;
	my $hash = shift;

	my $response = $hash->{methodCall} or $self->croak('no data in call');

	my $methodname = $response->{methodName};
	my @args =
	map { $self->unparse_value( $_->{value} ) } $self->list( $response->{params}->{param} );
	return ( $methodname, @args );
}

sub unparse_value {
	my $self  = shift;
	my $value = shift;
	my $result;

	return $value if ( ref($value) ne 'HASH' );    # for unspecified params
	if ( $value->{struct} ) {
		$result = $self->unparse_struct( $value->{struct} );
		return !%$result
		? undef
		: $result;                               # fix for empty hashrefs from XML::TreePP
	}
	elsif ( $value->{array} ) {
		return $self->unparse_array( $value->{array} );
	}
	else {
		return $self->unparse_scalar($value);
	}
}
sub unparse_scalar {
	my $self     = shift;
	my $scalar   = shift;
	my ($result) = values(%$scalar);
	return ( ref($result) eq 'HASH' && !%$result )
	? undef
	: $result;    # fix for empty hashrefs from XML::TreePP
}

sub unparse_struct {
	my $self   = shift;
	my $struct = shift;

	return { map { $_->{name} => $self->unparse_value( $_->{value} ) } $self->list( $struct->{member} ) };
}

sub unparse_array {
	my $self  = shift;
	my $array = shift;
	my $data  = $array->{data};
	$data = {} unless ref $data eq 'HASH';
#	ref $data eq 'HASH' or confess('Broken struct: '.Dumper( (caller_args(2))[1] ));

	return [ map { $self->unparse_value($_) } $self->list( $data->{value} ) ];
}

sub list {
	my $self  = shift;
	my $param = shift;
	return () if ( !$param );
	return @$param if ( ref($param) eq 'ARRAY' );
	return ($param);
}

sub xml_in { shift->{xml_in} }

sub xml_out { shift->{xml_out} }

### HASH => XML ###

sub compose_xml {
	my $self = shift;
	my $tree = shift or return $self->die( 'Invalid tree' );
	my $from = $self->{internal_encoding} || $INTERNAL_ENCODING;
	my $to   = shift || $self->{external_encoding} || $XML_ENCODING;
	my $decl = $self->{xml_decl};
	$decl = '<?xml version="1.0" encoding="' . $to . '" ?>' unless defined $decl;

	local $self->{__first_out};
	if ( exists $self->{first_out} ) {
		my $keys = $self->{first_out};
		$keys = [$keys] unless ref $keys;
		$self->{__first_out} = { map { $keys->[$_] => $_ } 0 .. $#$keys };
	}

	local $self->{__last_out};
	if ( exists $self->{last_out} ) {
		my $keys = $self->{last_out};
		$keys = [$keys] unless ref $keys;
		$self->{__last_out} = { map { $keys->[$_] => $_ } 0 .. $#$keys };
	}

	my $tnk = $self->{text_node_key} if exists $self->{text_node_key};
	$tnk = $TEXT_NODE_KEY unless defined $tnk;
	local $self->{text_node_key} = $tnk;

	my $apre = $self->{attr_prefix} if exists $self->{attr_prefix};
	$apre = $ATTR_PREFIX unless defined $apre;
	local $self->{__attr_prefix_len} = length($apre);
	local $self->{__attr_prefix_rex} = defined $apre ? qr/^\Q$apre\E/s : undef;

	local $self->{__indent};
	if ( exists $self->{indent} && $self->{indent} ) {
		$self->{__indent} = ' ' x $self->{indent};
	}
	my $start = time;
	$tree = $tree->() if ref $tree eq 'CODE';
	my $text = $self->hash_to_xml( undef, $tree );
	warn sprintf "xml of length %d created in %0.3fs\n",length($text),time - $start if DEBUG_TIMES;
	
	my $enc;
	ref ( $enc = Encode::find_encoding( $from ) ) or croak "Unknown encoding $from";
	$enc = undef if $enc->name eq 'utf-8-strict' or $enc->name eq 'utf-8';
	$enc and $text = $enc->decode($text);
	
	ref ( $enc = Encode::find_encoding( $to ) ) or croak "Unknown encoding $to";
	$enc = undef if $enc->name eq 'utf-8-strict' or $enc->name eq 'utf-8';
	$enc and $text = $enc->encode($text);

	$text = join( "\n", $decl, $text ) if $decl ne '';
	utf8::encode($text) if utf8::is_utf8($text);
	
	return $text;
}

sub hash_to_xml {
	my $self      = shift;
	my $name      = shift;
	my $hash      = shift;
	defined $self->{text_node_key} and length $self->{text_node_key} or warn "TextNodeKey not defined inside hash_to_xml";
	#warn ("hash_to_xml(".Data::Dumper::Dumper($hash).")\n");
	#ref $hash eq 'HASH' or warn ("hash_to_xml(".Data::Dumper::Dumper($hash).")\n"),croak("Not a HASH: $hash");
	my $out       = [];
	my $attr      = [];
	my $allkeys   = [ keys %$hash ];
	my $fo = $self->{__first_out} if ref $self->{__first_out};
	my $lo = $self->{__last_out}  if ref $self->{__last_out};
	my $firstkeys = [ sort { $fo->{$a} <=> $fo->{$b} } grep { exists $fo->{$_} } @$allkeys ] if ref $fo;
	my $lastkeys  = [ sort { $lo->{$a} <=> $lo->{$b} } grep { exists $lo->{$_} } @$allkeys ] if ref $lo;
	$allkeys = [ grep { ! exists $fo->{$_} } @$allkeys ] if ref $fo;
	$allkeys = [ grep { ! exists $lo->{$_} } @$allkeys ] if ref $lo;
	unless ( exists $self->{use_ixhash} && $self->{use_ixhash} ) {
		$allkeys = [ sort @$allkeys ];
	}
	my $prelen = $self->{__attr_prefix_len};
	my $pregex = $self->{__attr_prefix_rex};

	foreach my $keys ( $firstkeys, $allkeys, $lastkeys ) {
		next unless ref $keys;
		my $elemkey = $prelen ? [ grep { $_ !~ $pregex } @$keys ] : $keys;
		my $attrkey = $prelen ? [ grep { $_ =~ $pregex } @$keys ] : [];

		foreach my $key ( @$elemkey ) {
			my $val = $hash->{$key};
			if ( !defined $val ) {
				push( @$out, "<$key />" );
			}
			elsif ( UNIVERSAL::isa( $val, 'ARRAY' ) ) {
				my $child = $self->array_to_xml( $key, $val );
				push( @$out, $child );
			}
			elsif ( UNIVERSAL::isa( $val, 'SCALAR' ) ) {
				my $child = $self->scalaref_to_cdata( $key, $val );
				push( @$out, $child );
			}
			elsif ( ref $val ) {
				my $child = $self->hash_to_xml( $key, $val );
				push( @$out, $child );
			}
			else {
				#warn "$key => $val: ".$self->scalar_to_xml( $key, $val )."\n";
				my $child = $self->scalar_to_xml( $key, $val );
				push( @$out, $child );
			}
		}

		foreach my $key ( @$attrkey ) {
			my $name = substr( $key, $prelen );
			my $val = &xml_escape( $hash->{$key} );
			push( @$attr, ' ' . $name . '="' . $val . '"' );
		}
	}
	my $jattr = join( '', @$attr );

	if ( defined $name && scalar @$out && ! grep { ! /^</s } @$out ) {
		# Use human-friendly white spacing
		if ( defined $self->{__indent} ) {
			s/^(\s*<)/$self->{__indent}$1/mg foreach @$out;
		}
		unshift( @$out, "\n" );
	}

	my $text = join( '', @$out );
	if ( defined $name ) {
		if ( scalar @$out ) {
			$text = "<$name$jattr>$text</$name>\n";
		}
		else {
			$text = "<$name$jattr />\n";
		}
	}
	$text;
}

sub array_to_xml {
	my $self  = shift;
	my $name  = shift;
	my $array = shift;
	my $out   = [];
	foreach my $val (@$array) {
		if ( !defined $val ) {
			push( @$out, "<$name />\n" );
		}
		elsif ( UNIVERSAL::isa( $val, 'ARRAY' ) ) {
			my $child = $self->array_to_xml( $name, $val );
			push( @$out, $child );
		}
		elsif ( UNIVERSAL::isa( $val, 'SCALAR' ) ) {
			my $child = $self->scalaref_to_cdata( $name, $val );
			push( @$out, $child );
		}
		elsif ( ref $val ) {
			my $child = $self->hash_to_xml( $name, $val );
			push( @$out, $child );
		}
		else {
			my $child = $self->scalar_to_xml( $name, $val );
			push( @$out, $child );
		}
	}

	my $text = join( '', @$out );
	$text;
}

sub scalaref_to_cdata {
	my $self = shift;
	my $name = shift;
	my $ref  = shift;
	my $data = defined $$ref ? $$ref : '';
	$data =~ s#(]])(>)#$1]]><![CDATA[$2#g;
	my $text = '<![CDATA[' . $data . ']]>';
	$text = "<$name>$text</$name>\n" if ( $name ne $self->{text_node_key} );
	$text;
}

sub scalar_to_xml {
	my $self   = shift;
	my $name   = shift;
	my $scalar = shift;
	my $copy   = $scalar;
	my $text   = &xml_escape($copy);
	$text = "<$name>$text</$name>\n" if ( $name ne $self->{text_node_key} );
	$text;
}

sub xml_escape {
	my $str = shift;
	return '' unless defined $str;
	# except for TAB(\x09),CR(\x0D),LF(\x0A)
	$str =~ s{
		([\x00-\x08\x0B\x0C\x0E-\x1F\x7F])
	}{
		sprintf( '&#%d;', ord($1) );
	}gex;
	$str =~ s/&(?!#(\d+;|x[\dA-Fa-f]+;))/&amp;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;
	$str =~ s/'/&apos;/g; #'
	$str =~ s/"/&quot;/g; #"
	$str;
}

### XML => HASH ###

sub parse_xml {
	my $self = shift;
	my $xml  = ref $_[0] ? $_[0] : \$_[0];
	return $self->die( 'Null XML source' ) unless defined $xml;
	
	if ($self->{no_xml_parser}) {
		require XML::TreePP;
		my %args = %$self;
		delete $args{url};
		return XML::TreePP->new( %args )->parse($xml);
	}
	
	
	local $self->{__force_array};
	local $self->{__force_array_all};
	if ( exists $self->{force_array} ) {
		my $force = $self->{force_array};
		$force = [$force] unless ref $force;
		$self->{__force_array} = { map { $_ => 1 } @$force };
		$self->{__force_array_all} = $self->{__force_array}->{'*'};
	}

	local $self->{__force_hash};
	local $self->{__force_hash_all};
	if ( exists $self->{force_hash} ) {
		my $force = $self->{force_hash};
		$force = [$force] unless ref $force;
		$self->{__force_hash} = { map { $_ => 1 } @$force };
		$self->{__force_hash_all} = $self->{__force_hash}->{'*'};
	}

	my $tnk = $self->{text_node_key} if exists $self->{text_node_key};
	$tnk = $TEXT_NODE_KEY unless defined $tnk;
	local $self->{text_node_key} = $tnk;

	my $apre = $self->{attr_prefix} if exists $self->{attr_prefix};
	$apre = $ATTR_PREFIX unless defined $apre;
	local $self->{attr_prefix} = $apre;

	if ( exists $self->{use_ixhash} && $self->{use_ixhash} ) {
		return $self->die( "Tie::IxHash is required." ) unless &load_tie_ixhash();
	}

	my $flat  = $self->xml_to_flat($xml);
	return $flat;# if $::DEBUG::WANT_FLAT;

# TODO
# 	my $class = $self->{base_class} if exists $self->{base_class};
# 	my $tree  = $self->flat_to_tree( $flat, '', $class );
# 	if ( ref $tree ) {
# 		if ( defined $class ) {
# 			bless( $tree, $class );
# 		}
# 		elsif ( exists $self->{elem_class} && $self->{elem_class} ) {
# 			bless( $tree, $self->{elem_class} );
# 		}
# 	}
# 	wantarray ? ( $tree, $$xml ) : $tree;

}

sub xml_to_flat {
	my $self    = shift;
	my $textref = shift;    # reference
	
	my @flat;
	
	my $opentag = 0;
	my $apref = defined $self->{attr_prefix} ? $self->{attr_prefix} : $ATTR_PREFIX;
	my $to   = $self->{internal_encoding} || $INTERNAL_ENCODING;
	ref ( my $enc = Encode::find_encoding( $to ) )
		or croak "Unknown encoding $to";
	$enc = undef if $enc->name eq 'utf-8-strict' or $enc->name eq 'utf-8';
	#undef $enc;
	warn "Running XML::Parser with target encoding ".($enc ? $enc->name : 'utf8' )." on \n$$textref\n" if DEBUG_ENCODING;
	
	my @stack;
	my %tree;
	my $context = { tree => {} };
	my $lastchar;
	
	my $p = XML::Parser->new(
		Handlers => {
			Start => subname ( "*Start", sub {
				my $ex = shift;
				if ($enc) { @_ = @_; $_ = $enc->encode($_) for @_ };
				my $tag = shift;
				
				my $node = {
					name  => $tag,
					tree   => undef,
				};
				Scalar::Util::weaken($node->{parent} = $context);
				if (@_) {
					my %attr;
					while (my ($k,$v) = splice @_,0,2) {
						$attr{ $apref.$k } = $v;
					}
					#$flat[$#flat]{attributes} = \%attr;
					$node->{attrs} = \%attr;
					#warn "Need something to do with attrs on $tag\n";
				};
				$lastchar = undef;
				$opentag = 1;
				
				push @stack, $context = $node;
			} ),
			End => subname ( "*End" => sub {
				my $ex = shift;
				if ($enc) { @_ = @_; $_ = $enc->encode($_) for @_ };
				my $name = shift;
				
				#my $node = pop @stack;
				my $text = [];
				if ( defined $lastchar ) {
					# set text
					$text = $lastchar;
					$lastchar = undef;
				};
				$opentag = 0;
				
				my $tree = $context->{tree};

				my $haschild = scalar keys %$tree;
				if ( ! $self->{__force_array_all} ) {
					foreach my $key ( keys %$tree ) {
						next if $self->{__force_array}->{$key};
						next if ( 1 < scalar @{ $tree->{$key} } );
						$tree->{$key} = shift @{ $tree->{$key} };
					}
				}
				if ( @$text ) {
					if ( @$text == 1 ) {
						# one text node (normal)
						$text = shift @$text;
					}
					else {
						# some text node splitted
						$text = join( '', @$text );
					}
					if ( $haschild ) {
						# some child nodes and also text node
						$tree->{$self->{text_node_key}} = $text;
					}
					else {
						# only text node without child nodes
						$tree = $text;
					}
				}
				elsif ( ! $haschild ) {
					# no child and no text
					$tree = "";
				}
				
				# Move up!
				my $child = $tree;
				#warn "parent for $name = $context->{parent}\n";
				my $elem = $context->{attrs};
				my $hasattr = scalar keys %$elem if ref $elem;
				my $forcehash = $self->{__force_hash_all} || ( $context->{parent}{name} && $self->{__force_hash}->{$context->{parent}{name}} );
				$context = $context->{parent};
				
				#warn "$context->{name} have ".Dumper ($elem);
				if ( UNIVERSAL::isa( $child, "HASH" ) ) {
					if ( $hasattr ) {
						# some attributes and some child nodes
						%$elem = ( %$elem, %$child );
					}
					else {
						# some child nodes without attributes
						$elem = $child;
					}
				}
				else {
					if ( $hasattr ) {
						# some attributes and text node
						$elem->{$self->{text_node_key}} = $child;
					}
					elsif ( $forcehash ) {
						# only text node without attributes
						$elem = { $self->{text_node_key} => $child };
					}
					else {
						# text node without attributes
						$elem = $child;
					}
				}
				
				push @{ $context->{tree}->{$name} ||= [] },$elem;
				$name = $context->{name};
				$tree = $context->{tree} ||= {};
				
				warn "unused args on /$name: @_" if @_;
			}),
			Char => subname ("*Char" => sub {
				my $ex = shift;
				if ($enc) { @_ = @_; $_ = $enc->encode($_) for @_ };
				my $text = shift;
				
				#do {
				#	local $Data::Dumper::Indent = 0;
				#	local $Data::Dumper::Terse = 1;
				#	warn qq{open="$opentag"; text=}.Dumper($text) if $text =~ /\S/;
				#} if DEBUG_ENCODING;
				if ($opentag) {
					$lastchar = [] unless defined $lastchar;
					push @$lastchar, $text
				}
				#warn "unused args on char: @_" if @_;
				#warn " @{$ex->{Context}} : char \"$text\" @_\n";
			}),
		},
	);
	eval { $p->parse($$textref); } or Carp::croak "$$textref, $@\n";
	my $tree = $context->{tree};
	if ( ! $self->{__force_array_all} ) {
		foreach my $key ( keys %$tree ) {
			next if $self->{__force_array}->{$key};
			next if ( 1 < scalar @{ $tree->{$key} } );
			$tree->{$key} = shift @{ $tree->{$key} };
		}
	}
	return $tree;
}

1;
