use inc::Module::Install;

use 5.7.3;
name     'XML-RPC-Fast';
all_from 'lib/XML/RPC/Fast.pm';
author   'Mons Anderson <mons@cpan.org>';

build_requires 'Test::More';
build_requires 'ex::lib';

# TODO
#if( $] >= 5.007003 ) {
#	requires 'Encode';
#} else {
#	requires 'Text::Iconv';
#}

requires 'Encode';
requires 'LWP::UserAgent';
requires 'Time::HiRes';
requires 'Scalar::Util';
requires 'XML::Parser', '2.36';

auto_install;

WriteAll;

