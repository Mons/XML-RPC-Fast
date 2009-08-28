use 5.008003; # I want Encode to work
use inc::Module::Install;

name     'XML-RPC-Fast';
all_from 'lib/XML/RPC/Fast.pm';
version   my $v = '0.4';
author   'Mons Anderson <mons@cpan.org>';

build_requires 'Test::More';
build_requires 'Test::NoWarnings';
build_requires 'lib::abs', '0.90';

# requires 'Encode';
requires 'LWP::UserAgent';
requires 'XML::LibXML';
requires 'XML::Hash::LX';
recommends 'Sub::Name';
recommends 'MIME::Base64';
recommends DateTime::Format::ISO8601;

provides 'XML::RPC::Fast' => {
	version => $v,
	file    => 'lib/XML/RPC/Fast.pm',
};

provides 'XML::RPC::Enc::LibXML' => {
	version => $v,
	file    => 'lib/XML/RPC/Enc/LibXML.pm',
};

provides 'XML::RPC::UA::LWP' => {
	version => $v,
	file    => 'lib/XML/RPC/UA/LWP.pm',
};

auto_install;

WriteAll;

