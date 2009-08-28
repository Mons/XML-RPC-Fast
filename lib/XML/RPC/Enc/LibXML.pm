package XML::RPC::Enc::LibXML;

use strict;
use warnings;
use base 'XML::RPC::Enc';
use XML::LibXML;
use XML::Hash::LX;
#use Encode ();

use XML::RPC::Fast ();
our $VERSION = $XML::RPC::Fast::VERSION;


=head1 NAME

XML::RPC::Enc::LibXML - Encode/decode XML-RPC using LibXML

=head1 SYNOPSIS

    use XML::RPC::Fast;
    use XML::RPC::Enc::LibXML;
    
    my $rpc = XML::RPC::Fast->new(
        $uri,
        encoder => XML::RPC::Enc::LibXML->new(
            # internal_encoding currently not implemented, always want wide chars
            internal_encoding => undef,
            external_encoding => 'windows-1251',
        )
    );

    $rpc->registerType( base64 => sub {
        my $node = shift;
        return MIME::Base64::decode($node->textContent);
    });

    $rpc->registerType( 'dateTime.iso8601' => sub {
        my $node = shift;
        return DateTime::Format::ISO8601->parse_datetime($node->textContent);
    });

    $rpc->registerClass( DateTime => sub {
        return ( 'dateTime.iso8601' => $_[0]->strftime('%Y%m%dT%H%M%S.%3N%z') );
    });

    $rpc->registerClass( DateTime => sub {
        my $node = XML::LibXML::Element->new('dateTime.iso8601');
        $node->appendText($_[0]->strftime('%Y%m%dT%H%M%S.%3N%z'));
        return $node;
    });

=head1 DESCRIPTION

Default encoder/decoder for L<XML::RPC::Fast>

If MIME::Base64 is installed, decoder for C<XML-RPC> type C<base64> will be setup

If DateTime::Format::ISO8601 is installed, decoder for C<XML-RPC> type C<dateTime.iso8601> will be setup

Also will be setup by default encoders for L<Class::Date> and L<DateTime> (will be encoded as C<dateTime.iso8601>)

Ty avoid default decoders setup:

    BEGIN {
        $XML::RPC::Enc::LibXML::TYPES{base64} = 0;
        $XML::RPC::Enc::LibXML::TYPES{'dateTime.iso8601'} = 0;
    }
    use XML::RPC::Enc::LibXML;

=head1 IMPLEMENTED METHODS

=head2 new

=head2 request

=head2 response

=head2 fault

=head2 decode

=head2 registerType

=head2 registerClass

=head1 SEE ALSO

=over 4

=item * L<XML::RPC::Enc>

Base class (also contains documentation)

=back

=cut

# xml => perl
# args: xml-nodes (children of <value><$type> ... </$type></value>)
# retv: any scalar
our %TYPES;

# perl => xml
# args: object
# retv: ( type => string ) || xml-node
our %CLASS;

our $E;

BEGIN {
	if ( !exists $TYPES{base64} and eval{ require MIME::Base64;1 } ) {
		$TYPES{base64} = sub {
			MIME::Base64::decode(shift->textContent);
		};
	}
	# DateTime is the most "standart" datetime object in perl, try to use it
	if ( !exists $TYPES{'dateTime.iso8601'} and eval{ require DateTime::Format::ISO8601;1 } ) {
		$TYPES{'dateTime.iso8601'} = sub {
			DateTime::Format::ISO8601->parse_datetime(shift->textContent)
		};
	}
}

#%TYPES = (
#	custom => sub { ... },
#	%TYPES,
#);

# We need no modules to predefine encoders for dates
%CLASS = (
	DateTime => sub {
		'dateTime.iso8601',$_[0]->strftime('%Y%m%dT%H%M%S.%3N%z');
	},
	'Class::Date' => sub {
		'dateTime.iso8601',$_[0]->strftime('%Y%m%dT%H%M%S').sprintf( '%+03d%02d', $_[0]->tzoffset / 3600, ( $_[0]->tzoffset % 3600 ) / 60  );
	},
	%CLASS,
);

sub new {
	my $pkg = shift;
	my $self = bless {
		@_,
		parser => XML::LibXML->new(),
		types  => { },
		class  => { },
		internal_encoding => undef,
	}, $pkg;
	$self->{external_encoding} = 'utf-8' unless defined $self->{external_encoding};
	return $self;
}


sub registerType {
	my ( $self,$type,$decode ) = @_;
	my $old;
	if (ref $self) {
		$old = $self->{types}{$type};
		$self->{types}{$type} = $decode;
	} else {
		$old = $TYPES{$type};
		$TYPES{$type} = $decode;
	}
	$old;
}

sub registerClass {
	my ( $self,$class,$encode ) = @_;
	my $old;
	if (ref $self) {
		$old = $self->{class}{$class};
		$self->{class}{$class} = $encode;
	} else {
		$old = $CLASS{$class};
		$CLASS{$class} = $encode;
	}
	$old;
}

# Encoder part

sub _unparse_param {
	my $p = shift;
	my $r = XML::LibXML::Element->new('value');

	if ( ref($p) eq 'HASH' ) {
		# struct -> ( member -> { name, value } )*
		my $s = XML::LibXML::Element->new('struct');
		$r->appendChild($s);
		for ( keys %$p ) {
			my $m = XML::LibXML::Element->new('member');
			my $n = XML::LibXML::Element->new('name');
			$n->appendText($_);
			$m->appendChild($n);
			$m->appendChild(_unparse_param($p->{$_}));
			$s->appendChild($m);
		}
	}
	elsif ( ref($p) eq 'ARRAY' ) {
		my $a = XML::LibXML::Element->new('array');
		my $d = XML::LibXML::Element->new('data');
		$a->appendChild($d);
		$r->appendChild($a);
		for (@$p) {
			$d->appendChild( _unparse_param($_) )
		}
	}
	elsif ( ref($p) eq 'CODE' ) {
		$r->appendChild(hash2xml($p->(), doc => 1)->documentElement);
	}
	elsif (ref $p) {
		if (exists $CLASS{ ref $p }) {
			my ($t,$x) = $CLASS{ ref $p }->($p);
			if (ref $t and eval{ $t->isa('XML::LibXML::Node') }) {
				$r->appendChild($t);
			} else {
				my $v = XML::LibXML::Element->new($t);
				$v->appendText($x);
				$r->appendChild($v);
			}
		}
		elsif ( UNIVERSAL::isa($p,'SCALAR') ) {
			my $v = XML::LibXML::Element->new(ref $p);
			$v->appendText($$p);
			$r->appendChild($v);
		}
		elsif ( UNIVERSAL::isa($p,'REF') ) {
			my $v = XML::LibXML::Element->new(ref $p);
			$v->appendChild(hash2xml($$p, doc => 1)->documentElement);
			$r->appendChild($v);
		}
		else {
			warn "Bad reference: $p";
			#$result = undef;
		}
	}
	else {
		#no warnings;
		if (!defined $p) {
			my $v = XML::LibXML::Element->new('string');
			$r->appendChild($v);
		}
		elsif ( $p =~ m/^[\-+]?\d+$/ and  abs($p) <= ( 0xffffffff >> 1 )  ) {
			my $v = XML::LibXML::Element->new('i4');
			$v->appendText($p);
			$r->appendChild($v);
		}
		elsif ( $p =~ m/^[\-+]?\d+\.\d+$/ ) {
			my $v = XML::LibXML::Element->new('double');
			$v->appendText($p);
			$r->appendChild($v);
		}
		else {
			my $v = XML::LibXML::Element->new('string');
			$v->appendText($p);
			$r->appendChild($v);
		}
	}
	return $r;
}

sub request {
	my $self = shift;
	local @CLASS{keys %{ $self->{class} }} = values %{ $self->{class} };
	my $method = shift;
	my $doc = XML::LibXML::Document->new('1.0',$self->{external_encoding});
	my $root = XML::LibXML::Element->new('methodCall');
	$doc->setDocumentElement($root);
	my $n = XML::LibXML::Element->new('methodName');
	$n->appendText($method);
	$root->appendChild($n);
	my $prms = XML::LibXML::Element->new('params');
	$root->appendChild($prms);
	for my $v (@_) {
		my $p = XML::LibXML::Element->new('param');
		$p->appendChild( _unparse_param($v) );
		$prms->appendChild($p);
	}
	return $doc->toString;
}

sub response {
	my $self = shift;
	#local $E = Encode::find_encoding($self->{internal_encoding}) if defined $self->{internal_encoding};
	local @CLASS{keys %{ $self->{class} }} = values %{ $self->{class} };
	my $doc = XML::LibXML::Document->new('1.0',$self->{external_encoding});
	my $root = XML::LibXML::Element->new('methodResponse');
	$doc->setDocumentElement($root);
	my $prms = XML::LibXML::Element->new('params');
	$root->appendChild($prms);
	for my $v (@_) {
		my $p = XML::LibXML::Element->new('param');
		$p->appendChild( _unparse_param($v) );
		$prms->appendChild($p);
	}
	return $doc->toString;
}

sub fault {
	my $self = shift;
	local @CLASS{keys %{ $self->{class} }} = values %{ $self->{class} };
	my ($code,$err) = @_;
	my $doc = XML::LibXML::Document->new('1.0',$self->{external_encoding});
	my $root = XML::LibXML::Element->new('methodResponse');
	$doc->setDocumentElement($root);
	my $f = XML::LibXML::Element->new('fault');
	my $v = XML::LibXML::Element->new('value');
	my $s = XML::LibXML::Element->new('struct');
	for (qw(faultCode faultString)){
		my $m = XML::LibXML::Element->new('member');
		my $n = XML::LibXML::Element->new('name');
		$n->appendText($_);
		$m->appendChild($n);
		$m->appendChild(_unparse_param(shift));
		$s->appendChild($m);
	}
	$v->appendChild($s);
	$f->appendChild($v);
	$root->appendChild($f);
	return $doc->toString;
}

# Decoder part

sub decode {
	my $self = shift;
	$self->_parse( $self->{parser}->parse_string(shift) )
}

sub _parse_param {
	my $v = shift;
	for my $t ($v->childNodes) {
		next if $t->nodeName eq '#text';
		my $type = $t->nodeName;
		#print $t->nodeName,"\n";
		if ($type eq 'string') {
			return ''.$t->textContent;
		}
		elsif ($type eq 'i4' or $type eq 'int') {
			return int $t->textContent;
		}
		elsif ($type eq 'double') {
			return 0+$t->textContent;
		}
		elsif ($type eq 'bool') {
			$v = $t->textContent;
			return $v eq 'false' ? 0 : !!$v ? 1 : 0;
		}
		elsif ($type eq 'struct') {
			my $r = {};
			for my $m ($t->childNodes) {
				my ($mn,$mv);
				if ($m->nodeName eq 'member') {
					for my $x ($m->childNodes) {
						#print "\tmember:".$x->nodeName,"\n";
						if ($x->nodeName eq 'name') {
							$mn = $x->textContent;
							#last;
						}
						elsif ($x->nodeName eq 'value') {
							$mv = _parse_param ($x);
							$mn and last;
						}
					}
					$r->{$mn} = $mv;
				}
			}
			return $r;
		}
		elsif ($type eq 'array') {
			my $r = [];
			for my $d ($t->childNodes) {
				#print "\tdata:".$d->nodeName,"\n";
				if ($d->nodeName eq 'data') {
					for my $x ($d->childNodes) {
						#print "\tdata:".$x->nodeName,"\n";
						if ($x->nodeName eq 'value') {
							push @$r, _parse_param ($x);
						}
					}
				}
			}
			return $r;
		}
#		elsif ($type eq 'base64') {
#			return decode_base64($t->textContent);
#		}
#		elsif ($type eq 'dateTime.iso8601') {
#			return $t->textContent;
#		}
		else {
			if (exists $TYPES{$type} and $TYPES{$type}) {
				return $TYPES{$type}( $t->childNodes );
			} else {
				my @children = $t->childNodes;
				if (@children > 1 xor $children[0]->nodeName ne '#text') {
					return bless \(xml2hash($t)->{$type}),$type;
				} else {
					return bless \($children[0]->textContent),$type;
				}
			}
		}
		last;
	}
	return $v->textContent;
}

sub _parse {
	my $self = shift;
	my $doc = shift;
	my $xp = XML::LibXML::XPathContext->new($doc);
	my @r;
	my $root = $doc->documentElement;
	local @TYPES{keys %{ $self->{types} }} = values %{ $self->{types} };
	for my $p ($xp->findnodes('//param')) {
	#for my $ps ($root->childNodes) {
	#	if ($ps->nodeName eq 'params') {
	#		for my $p ($ps->childNodes) {
	#			if ($p->nodeName eq 'param') {
					#print $p->nodeName,"\n";
					for my $v ($p->childNodes) {
						if ($v->nodeName eq 'value') {
							#print $p->nodeName,'=',_parse_param($v),"\n";
							push @r, _parse_param ($v);
						}
					}
	#			}
	#		}
	#	}
	}
	for my $m ($xp->findnodes('//methodName')) {
		unshift @r, $m->textContent;
		last;
	}
	unless(@r) {
	for my $f ($xp->findnodes('//fault')) {
		my ($c,$e);
		
		for ($f->childNodes) {
			if ( $_->nodeName eq 'value' ) {
				my $flt  = _parse_param ( $_ );
				$c = $flt->{faultCode};
				$e = $flt->{faultString};
				last;
			} else {
				$c = $_->textContent if $_->nodeName eq 'faultCode';
				$e = $_->textContent if $_->nodeName eq 'faultString';
			}
		}
		return { fault => { faultCode => $c, faultString => $e } };
	}
	}
	#warn "@r";
	return @r;
}

=head1 COPYRIGHT & LICENSE

Copyright (c) 2008-2009 Mons Anderson.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Mons Anderson, C<< <mons@cpan.org> >>

=cut

1;
