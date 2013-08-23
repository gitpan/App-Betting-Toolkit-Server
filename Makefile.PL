use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::Betting::Toolkit::Server',
    AUTHOR              => q{Paul G Webster <daemon@cpan.org>},
    VERSION_FROM        => 'lib/App/Betting/Toolkit/Server.pm',
    ABSTRACT_FROM       => 'lib/App/Betting/Toolkit/Server.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'bsd')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-Betting-Toolkit-Server-*' },
);
