use 5.008003; # I want Encode to work
use inc::Module::Install;

name     'XML-RPC-Fast';
all_from 'lib/XML/RPC/Fast.pm';
version   my $v = '0.5';
author   'Mons Anderson <mons@cpan.org>';

build_requires 'Test::More';
build_requires 'Test::NoWarnings';
build_requires 'lib::abs', '0.90';
build_requires 'Encode';

# requires 'Encode';
requires 'LWP::UserAgent';
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Headers';

requires 'XML::LibXML', '1.58';
requires 'XML::Hash::LX' , '0.05';

recommends 'Sub::Name';
recommends 'MIME::Base64';
recommends 'DateTime::Format::ISO8601';
recommends 'AnyEvent', '5.0';
recommends 'AnyEvent::HTTP';

provides 'XML::RPC::Fast' => {
	version => $v,
	file    => 'lib/XML/RPC/Fast.pm',
};

provides 'XML::RPC::Enc' => {
	version => $v,
	file    => 'lib/XML/RPC/Enc.pm',
};

provides 'XML::RPC::UA' => {
	version => $v,
	file    => 'lib/XML/RPC/UA.pm',
};

provides 'XML::RPC::Enc::LibXML' => {
	version => $v,
	file    => 'lib/XML/RPC/Enc/LibXML.pm',
};

provides 'XML::RPC::UA::LWP' => {
	version => $v,
	file    => 'lib/XML/RPC/UA/LWP.pm',
};

provides 'XML::RPC::UA::AnyEvent' => {
	version => $v,
	file    => 'lib/XML/RPC/UA/AnyEvent.pm',
};

provides 'XML::RPC::UA::AnyEventSync' => {
	version => $v,
	file    => 'lib/XML/RPC/UA/AnyEventSync.pm',
};

auto_install;

WriteAll;

