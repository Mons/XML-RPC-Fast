#!/usr/bin/env perl -w

use strict;
use lib::abs '.','../lib';
BEGIN {
	$XML::RPC::Enc::LibXML::TYPES{base64} = 0;
	$XML::RPC::Enc::LibXML::TYPES{'dateTime.iso8601'} = 0;
}
use XML::RPC::Enc::LibXML;
use XML::RPC;
use Old;
#use XML::Twig;
use R::Dump;
use Benchmark qw(:all);

my $xml = q{<?xml version="1.0" encoding="UTF-8"?>
<methodCall>
  <methodName>test</methodName>
  <params>
    <param>
      <value>
        <i4>1</i4>
      </value>
    </param>
    <param>
      <value>
        <double>0.1</double>
      </value>
    </param>
    <param>
      <value>
        <string><![CDATA[a]]></string>
      </value>
    </param>
    <param>
      <value>
        <struct>
          <member>
            <name>-is</name>
            <value>
              <i4>1</i4>
            </value>
          </member>
          <member>
            <name>my</name>
            <value>
              <array>
                <data>
                  <value>
                    <string><![CDATA[test]]></string>
                  </value>
                  <value>
                    <i4>1</i4>
                  </value>
                </data>
              </array>
            </value>
          </member>
        </struct>
      </value>
    </param>
    <param>
      <value>
        <bool>1</bool>
      </value>
    </param>
    <param>
      <value>
        <base64>dGVzdA==</base64>
      </value>
    </param>
    <param>
      <value>
        <dateTime.iso8601>20090816T010203.04+0330</dateTime.iso8601>
      </value>
    </param>
    <param>
      <value>
        <custom>cusval</custom>
      </value>
    </param>
  </params>
</methodCall>
};

my $c = XML::RPC->new;
my $o = XML::RPC::Fast::Old->new;
my $e = XML::RPC::Enc::LibXML->new;

cmpthese timethese 2000, {
	xr => sub {
		my @r = $c->unparse_call($c->{tpp}->parse($xml))
		#$c->unparse_call($c->parse_xml($xml));
	},
	xo => sub {
		my @r = $o->unparse_call($o->parse_xml($xml));
	},
	xl => sub {
		my @r = $e->decode($xml);
	}
};


#print Dump + $c->unparse_call($c->{tpp}->parse($xml));


__END__
my $dec = XML::RPC::Dec::LibXML->new();
my $c = XML::RPC::Fast->new;
#my $t = XML::Twig->new( pretty_print => 'indented' );

#use MIME::Base64 'encode_base64','decode_base64';

=for rem
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

my $out = $t->parse($c->create_call_xml( test => @prm ))->sprint;
#print $out;
=cut


cmpthese timethese 2000, {
	xr => sub {
		$c->unparse_call($c->parse_xml($xml));
	},
	xl => sub {
		$dec->decode($xml);
	}
};

