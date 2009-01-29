use inc::Module::Install;

name     'XML-RPC-Fast';
all_from 'lib/XML/RPC/Fast.pm';
author   'Mons Anderson <mons@cpan.org>';

build_requires 'Test::More';
build_requires 'ex::lib';

requires 'Encode';

auto_install;

WriteAll;

