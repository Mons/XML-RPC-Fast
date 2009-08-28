#!/usr/bin/env perl -w

use strict;
use lib::abs '../..';
use lib '/data/home/mons/work/trunk/modules/XML-Hash-LX/lib';
use XML::RPC::Fast;
use XML::Hash::LX;
use XML::Twig;
use R::Dump;
use Benchmark qw(:all);
use XML::RPC::Fast2;

my $c = XML::RPC::Fast2->new(
	'www',
	call => sub {
		my %args = @_;
		$args{cb}(q{<?xml version="1.0" encoding="utf-8"?>
		<methodResponse>
		  <fault>
		      <faultCode>400</faultCode>
		          <faultString>Bad Request: test call</faultString>
		            </fault>
		            </methodResponse>
		            });
		warn "call @_";
	},
);
my $t = XML::Twig->new( pretty_print => 'indented' );
use MIME::Base64 'encode_base64','decode_base64';

my @prm = (
	1, 0.1,
	a => { my => [ test => 1 ], -is => 1},
	bless( do{\(my $o = '12345')}, 'estring' ),
	bless( do{\(my $o = { inner => 1 })}, 'xval' ),
	sub {{ bool => '1' }},
	sub {{ base64 => encode_base64('test') } },
	sub {{ 'dateTime.iso8601' => '20090816T010203.04+0330' }},
	bless( {}, 'zzz' ),
	sub {{ custom => 'cusval' }},
);

my $xml = $c->local_call_send(test => @prm);
print $t->parse($xml)->sprint;
my $res = $c->receive($xml, sub {
	warn "Request: @_";
	return 1;
});
print $t->parse($res)->sprint;

my $noxml = $c->receive(undef, sub {
	die "Error test 1";
	warn "Request: @_";
	return 1;
});
print $t->parse($noxml)->sprint;

my $nocb = $c->receive($xml);
print $t->parse($nocb)->sprint;
$c->call( test => 1,1,1 );
#my $res = $c->receive($xml, sub {
#	warn "Request: @_";
#	return 1;
#});
#print $t->parse($res)->sprint;

__END__
my $c = XML::RPC::Fast->new;
my $t = XML::Twig->new( pretty_print => 'indented' );


sub parse {
	my $p    = shift;
	my $result;

	if ( ref($p) eq 'HASH' ) {
		$result = {
			struct => [
				map { +{
					member => {
						( name => $_ ),
						%{ parse( $p->{$_} ) }
					}
				} } keys %$p
			]
		};
	}
	elsif ( ref($p) eq 'ARRAY' ) {
		$result = {
			array => {
				data => [
					map { { value => parse($_)->{value} } } @$p
				]
			}
		};
	}
	elsif ( ref($p) eq 'CODE' ) {
		$result = $p->();
	}
	elsif (ref $p) {
		if ( UNIVERSAL::isa($p,'SCALAR') ) {
			$result = { ref $p, $$p };
		}
		elsif ( UNIVERSAL::isa($p,'REF') ) {
			$result = { ref $p, $$p };
		}
		else {
			warn "Bad reference: $p";
			$result = undef;
		}
	}
	else {
		local $^W = undef;
		if ( $p =~ m/^[\-+]?\d+$/ and  abs($p) <= ( 0xffffffff >> 1 )  ) {
			$result =  { i4 => $p };
		}
		elsif ( $p =~ m/^[\-+]?\d+\.\d+$/ ) {
			$result =  { double => $p };
		}
		else {
			$result =  { string => $p };
		}
	}
	return { value => $result };
}

sub unparse1 {
	my $h = shift;
	my $r;
	if (my $ref = ref $h) {
		if ($ref eq 'ARRAY') {
			$r = [ map unparse ($_),@$h ];
		}
		elsif ($ref eq 'HASH') {
			if (keys %$h == 1) {
				my ($type,$val) = %$h;
				if ($type eq 'string') {
					$r = "$val";
				}
				elsif ($type eq 'i4') {
					$r = int $val;
				}
				elsif ($type eq 'double') {
					$r = 0+$val;
				}
				elsif ($type eq 'struct') {
					$r = unparse( $val->{member}{value} );
				}
				elsif ($type eq 'array') {
					$r = unparse( $val->{data}{value} );
					$r = [$r] unless ref $r eq 'ARRAY';
				}
				else {
					if (ref($val)) {
						$r = { ref => $h };
					} else {
						$r = bless \$val,$type;
					}
				}
			} else {
				$r = $h;
			}
		}
	} else {
		
	}
	$r;
}

sub unparse2 {
	my $h = shift;
	my $r;
	if (my $ref = ref $h) {
		if ($ref eq 'ARRAY') {
			$r = [ map unparse ($_),@$h ];
		}
		elsif ($ref eq 'HASH') {
			if (keys %$h == 1) {
				my ($t,$v) = %$h;
				if ($t eq 'value') {
					if (ref $v eq 'HASH' and keys %$v == 1) {
						my ($type,$val) = %$v;
						if ($type eq 'string') {
							$r = "$val";
						}
						elsif ($type eq 'i4') {
							$r = int $val;
						}
						elsif ($type eq 'double') {
							$r = 0+$val;
						}
						elsif ($type eq 'struct') {
							#return $val;
							$r = {};
							#ref $val eq 'ARRAY' and return $val;
							for my $m ( ref $val eq 'ARRAY' ? @{ $val } : $val ) {
								$m = $m->{member};
								$m = { map { %$_, } @$m } if ref $m eq 'ARRAY';
								$r->{$m->{name} } = unparse({ value => $m->{value} });
							}
							#$r = $val;#unparse($val->{member});#unparse( $val->{member}{value} );
						}
						elsif ($type eq 'array') {
							$r = unparse( $val->{data} );
							$r = [$r] unless ref $r eq 'ARRAY';
						}
						else {
							if (ref($val)) {
								$r = { ref => $h };
							} else {
								$r = bless \$val,$type;
							}
						}
					
					} else {
						$r = $v;
					}
				} else {
					$r = { wrong_type => $h };
				}
			} else {
				$r = $h;
			}
		}
	} else {
		
	}
	$r;
}

sub unparse {
	my $h = shift;
	my $r;
	if (my $ref = ref $h) {
		if ($ref eq 'ARRAY') {
			$r = [ map unparse ($_),@$h ];
		}
		elsif ($ref eq 'HASH') {
			if (keys %$h == 1) {
				my ($t,$v) = %$h;
				if ($t eq 'value') {
					if (ref $v eq 'HASH' and keys %$v == 1) {
						my ($type,$val) = %$v;
						if ($type eq 'string') {
							$r = "$val";
						}
						elsif ($type eq 'i4') {
							$r = int $val;
						}
						elsif ($type eq 'double') {
							$r = 0+$val;
						}
						elsif ($type eq 'struct') {
							#return $val;
							$r = {};
							#ref $val eq 'ARRAY' and return $val;
							for my $m ( ref $val eq 'ARRAY' ? @{ $val } : $val ) {
								$m = $m->{member};
								$m = { map { %$_, } @$m };# if ref $m eq 'ARRAY';
								$r->{$m->{name} } = unparse({ value => $m->{value} });
							}
						}
						elsif ($type eq 'array') {
							$r = unparse( $val->{data} );
							$r = [$r] unless ref $r eq 'ARRAY';
						}
						elsif ($type eq 'bool') {
							$r = $v eq 'false' ? 0 : !!$v ? 1 : 0;
						}
						elsif ($type eq 'base64') {
							$r = decode_base64($val);
						}
						elsif ($type eq 'dateTime.iso8601') {
							if (0) {
								# TODO: date composer
							}
							else {
								#use DateTime::Format::ISO8601;
								#$r = DateTime::Format::ISO8601->parse_datetime($val);
								$r = $val;
							}
							#$r = decode_base64($val);
						}
						else {
							if (0) {
								# TODO: custom types
							} else {
								$r = bless \$val,$type;
							}
						}
					
					}
					elsif (ref $v eq 'ARRAY') {
						$r = [ map unparse( { value => $_ } ),@$v ];
					}
					elsif (!ref $v) {
						$r = $v;
					}
					else {
						if (0) {
							# TODO: custom refs
						} else {
							$r = $v;
						}
					}
				} else {
					warn "Not a `value' node: $h";
					$r = { not_a_value => $h };
				}
			} else {
				warn "Got value with multiple keys: @{[ keys %$h ]}";
				$r = { map { $_ => unparse( { value => $h->{$_} } ) } keys %$h };
			}
		}
	} else {
		return $h;
	}
	$r;
}

use MIME::Base64 'encode_base64','decode_base64';
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

my $arg = {
	methodCall => [
		{ methodName => 'test' },
		{ params     => [  [ map {{ param => parse($_) }} @prm ] ] },
	]
};



#warn Dump + $arg;
#exit;
#my $xml = $c->create_call_xml( test => @prm );
#$xml = $t->parse($xml)->sprint;
#print $xml;
#my $hash = xml2hash $xml, cdata => '#', order => 1;
#print Dump + $hash;
my $p = XML::Parser->new(Style => 'EasyTree');
my $l = XML::LibXML->new;
my $out = $t->parse(hash2xml $arg)->sprint;
print $out;
$out = $t->parse($c->create_call_xml( test => @prm ))->sprint;
print $out;

sub parse_param {
	my $v = shift;
			for my $t ($v->childNodes) {
				next if $t->nodeName eq '#text';
				my $type = $t->nodeName;
				#print $t->nodeName,"\n";
						if ($type eq 'string') {
							return ''.$t->textContent;
						}
						elsif ($type eq 'i4') {
							return int $t->textContent;
						}
						elsif ($type eq 'double') {
							return 0+$t->textContent;
						}
						elsif ($type eq 'bool') {
							$v = $t->textContent;
							return $v eq 'false' ? 0 : !!$v ? 1 : 0;
						}
						elsif ($type eq 'base64') {
							return decode_base64($t->textContent);
						}
						elsif ($type eq 'dateTime.iso8601') {
							if (0) {
								# TODO: date composer
							}
							else {
								#use DateTime::Format::ISO8601;
								#$r = DateTime::Format::ISO8601->parse_datetime($val);
								return $t->textContent;
							}
							#$r = decode_base64($val);
						}
						elsif ($type eq 'struct') {
							#return 'TODO:struct';
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
											$mv = parse_param($x);
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
											push @$r, parse_param($x);
										}
									}
								}
							}
							return $r;
						}
						else {
							if (0) {
								# TODO: custom types
							} else {
								my @children = $t->childNodes;
								if (@children > 1) {
									return bless \(xml2hash($t)->{$type}),$type;
								} else {
									return bless \($children[0]->textContent),$type;
								}
							}
						}
				last;
			}
}

sub xparse {
	my $doc = shift;
	my $xp = XML::LibXML::XPathContext->new($doc);
	my @r;
	my $root = $doc->documentElement;
	for my $p ($xp->findnodes('//param')){
	#for my $ps ($root->childNodes) {
	#	if ($ps->nodeName eq 'params') {
	#		for my $p ($ps->childNodes) {
	#			if ($p->nodeName eq 'param') {
					#print $p->nodeName,"\n";
					for my $v ($p->childNodes) {
						if ($v->nodeName eq 'value') {
							push @r, parse_param($v);
						}
					}
	#			}
	#		}
	#	}
	}
	return \@r;
	for ($root->childNodes) {
		print $_->nodeName,"\n";
	}
	return;
}
#print + Dump xparse $l->parse_string($out);
#exit;
#print Dump + $c->unparse_call($c->parse_xml($out));
#print Dump + unparse(xml2hash( $out )->{methodCall}{params}{param});
#$c->unparse_call($c->parse_xml($out));
#exit;
cmpthese timethese 2000, 
{
#	lx => sub {
#		my $hash = xml2hash $out, array => [];
#		#unparse($hash->{methodCall}{params}{param});
#	},
	xr => sub {
		my $r = $c->parse_xml($out);
		$c->unparse_call($r);
	},
#	xp => sub {
#		my $hash = $p->parse($out);
#		#unparse($hash->{methodCall}{params}{param});
#	},
	xl => sub {
		xparse $l->parse_string($out);
	}
};

#my $hash = xml2hash $out, array => [];

##$hash->{methodCall} = { map { %$_, } @{ $hash->{methodCall} } };
##print Dump + $hash->{methodCall}{params}{param};

#print Dump + unparse($hash->{methodCall}{params}{param});

##print lc $xml eq  lc $out ? 'equal' : 'not equal' , "\n";

__END__
print hash2xml {
			methodCall => {
				methodName => 'test',
				params     => { param => [ map { $c->parse($_) } 'a'..'x' ] }
			}
		}