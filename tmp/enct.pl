#!/usr/bin/env perl -w

use utf8;
use strict;
use lib::abs '../../..';
use lib '/data/home/mons/work/trunk/modules/XML-Hash-LX/lib';
use XML::RPC::Fast;
    BEGIN {
        $XML::RPC::Enc::LibXML::TYPES{base64} = 0;
        $XML::RPC::Enc::LibXML::TYPES{'dateTime.iso8601'} = 0;
    }
use XML::RPC::Enc::LibXML;
use XML::Twig;
use R::Dump;
use Benchmark qw(:all);
use MIME::Base64 'encode_base64';
use Class::Date 'now';

my $enc = XML::RPC::Enc::LibXML->new(
	#external_encoding => 'windows-1251',
);
#my $c = XML::RPC::Fast->new;
my $t = XML::Twig->new( pretty_print => 'indented' );

#use MIME::Base64 'encode_base64','decode_base64';

my @prm = (
	1, 0.1,
	#Encode::encode( cp1251 => "кириллицо" ),
	"кириллицо",
	now(),
	a => { my => [ test => 1 ], -is => 1},
	bless( do{\(my $o = '12345')}, 'estring' ),
	bless( do{\(my $o = { inner => 1 })}, 'xval' ),
	sub {{ bool => '1' }},
	sub {{ base64 => encode_base64('test') } },
	sub {{ 'dateTime.iso8601' => '20090816T010203.04+0330' }},
#	bless( {}, 'zzz' ),
#	sub {{ custom => 'cusval' }},
	#sub {[ { subs => 'subval' }, { -x => 1 } ]},
);
$enc->registerType(base64 => sub {
			MIME::Base64::decode(shift->textContent);
		}
);
print $enc->response( @prm );
exit;
#print $t->parse(my $xml = $enc->encode( test => @prm ))->sprint;
print $t->parse(my $xml = $enc->response( @prm ))->sprint;
#print $t->parse(my $xml = $enc->fault( 111, 'err' ))->sprint;
print Dump( $enc->decode($xml) );
__END__

my $xml1 = q{<?xml version="1.0" encoding="UTF-8"?>
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

#my $out = $t->parse($c->create_call_xml( test => @prm ))->sprint;
#print $out;
#exit;
=for rem
=cut


cmpthese timethese 2000, {
	xr => sub {
		$c->create_call_xml( test => @prm )
	},
	xl => sub {
		$enc->encode(test => @prm);
	}
};

