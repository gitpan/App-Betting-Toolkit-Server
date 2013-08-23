#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::Betting::Toolkit::Server' ) || print "Bail out!\n";
}

diag( "Testing App::Betting::Toolkit::Server $App::Betting::Toolkit::Server::VERSION, Perl $], $^X" );
