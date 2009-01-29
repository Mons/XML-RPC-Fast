use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'XML::RPC::Fast',
    AUTHOR              => 'Mons Anderson <mons@cpan.org>',
    VERSION_FROM        => 'lib/XML/RPC/Fast.pm',
    ABSTRACT_FROM       => 'lib/XML/RPC/Fast.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'XML::Parser' => 0,
        'LWP::UserAgent' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'XML-RPC-Fast-*' },
);
