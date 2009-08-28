package XML::RPC::Dec::LibXML;

use strict;
use XML::LibXML;
#use DateTime::Format::ISO8601;
use MIME::Base64 'decode_base64';

sub new {
	return bless \(do{ my $o = XML::LibXML->new(); }), shift
}

sub decode {
	my $self = shift;
	$self->parse( $$self->parse_string(shift) )
}

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

sub parse {
	my $self = shift;
	my $doc = shift;
	my $xp = XML::LibXML::XPathContext->new($doc);
	my @r;
	my $root = $doc->documentElement;
	for my $p ($xp->findnodes('//param')) {
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
	for my $f ($xp->findnodes('//fault')) {
		my ($c,$e);
		for ($f->childNodes) {
			$c = $_->textContent if $_->nodeName eq 'faultCode';
			$e = $_->textContent if $_->nodeName eq 'faultString';
		}
		return { fault => { faultCode => $c, faultString => $e } };
	}
	for my $m ($xp->findnodes('//methodName')) {
		unshift @r, $m->texContent;
		last;
	}
	return @r;
}

1;
