package App::Betting::Toolkit::Server;

use 5.006;
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Try::Tiny;

use POE qw(Component::Server::TCP);

use App::Betting::Toolkit::GameState;

=head1 NAME

=over 1

App::Betting::Toolkit::Server - Recieve and process  App::Betting::Toolkit::GameState objects

=back

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

=over 1

Quick summary of what the module does.

Perhaps a little code snippet.

	use App::Betting::Toolkit::Server;

	my $server = App::Betting::Toolkit::Server->new();

	print "Server id: ".$server->ID;

=back

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub function1 {
}

=head1 AUTHOR

=over 1

Paul G Webster, C<< <daemon at cpan.org> >>

=back

=head1 BUGS

=over 1

Please report any bugs or feature requests to C<bug-app-betting-toolkit-server at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Betting-Toolkit-Server>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=back

=head1 SUPPORT

=over 1

You can find documentation for this module with the perldoc command.

    perldoc App::Betting::Toolkit::Server


You can also look for information at:

=back

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Betting-Toolkit-Server>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Betting-Toolkit-Server>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Betting-Toolkit-Server>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Betting-Toolkit-Server/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

=over 1

Copyright 2013 Paul G Webster.

This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/bsd-license.php>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of Paul G Webster's Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=back

=cut

sub new {
	my $class = shift;
	my $args  = shift;
	my $self;

	die "Need to have parent passed" if (!$args->{parent});

	$self->{keystore} = {};

	if ( (!$args->{port}) || ($args->{port} !~ m#^\d+$#) || ($args->{port} > 65535) || ($args->{port} < 1) ) {
		$args->{port} = 22122;
	} 

	$args->{alias} = 'betserver' if (!$args->{alias});

	warn "Starting server, port:",$args->{port}," alias:",$args->{alias};

	bless $self, $class;

	$self->{session} = POE::Component::Server::TCP->new(
		Alias		=> $args->{alias},
		Port		=> $args->{port},
		ClientFilter	=> "POE::Filter::Line",
		ClientConnected => sub { 
			my ($heap) = $_[HEAP];
			$heap->{json} = JSON->new->pretty(0)->allow_nonref;
			
		},
		ClientInput => sub {
			my ($kernel, $session, $heap, $raw) = @_[KERNEL, SESSION, HEAP, ARG0];

			# initilize $req
			my $req = { error=>1, gamestate=>{  } };

			eval { decode_json($raw) };
			if ($@) {
				$kernel->yield('shutdown');
				return;
			}

			$req = $heap->{json}->decode($raw);

			# Check the packet has a valid query type
			if (!defined $req->{query}) {
				my $error = $heap->{json}->encode({ error=>1, msg=>"Invalid query missing 'query'" });
				$heap->{client}->put($error);
				return;
			}

			$kernel->yield('handle_'.lc($req->{query}),$req);
		},
		InlineStates => {
			send_to_parent  =>      sub { 
				my ($kernel, $session, $heap, $req) = @_[KERNEL, SESSION, HEAP, ARG0];

				$kernel->post($args->{parent},$args->{handler},$req);
			},
			handle_register	=>	sub {
				my ($kernel, $session, $self, $heap, $req) = @_[KERNEL, SESSION, OBJECT, HEAP, ARG0];

				my $error = { query=>'register', error => 1, msg=> "Unknown error" };

				if ( $heap->{auth} ) { 
					$error = { query=>'register', error=>1, msg=>"Already registered" };
				} elsif ( (defined $req->{keys}) && (ref $req->{keys} eq 'ARRAY')) {
					my $unique = uc( join('_',@{ $req->{keys} }) );
					$self->{authed}->{$unique} = {
						key	=>	int(rand(999999)),
						created	=>	time
					};
					$error = { error=>0, query=>'register', key=>$self->{authed}->{$unique} };
				} elsif (defined $req->{keys}) {
					$error = { error=>1, query=>'register', msg=>"keys must be an array" };
				} else {
					my $unique = uc( join('_','AUTOGEN',time,int(rand(999)),int(rand(999)),int(rand(999))) );
					$self->{authed}->{$unique} = {
						key	=>	int(rand(999999)),
						created	=>	time
					};
					$error = { error=>0, query=>'register', key=>$self->{authed}->{$unique} };
				}

				$heap->{auth} = 1 if (!$error->{error});

				$heap->{client}->put($heap->{json}->encode($error));

				$kernel->yield('send_to_parent',$req);
	
#				# Validate the request
#				if (! App::Betting::Toolkit::GameState->loadable($req->{gamestate}) ) {
#					$kernel->yield("shutdown");
#					return;
#				}
#				my $gamestate = App::Betting::Toolkit::GameState->load($req->{gamestate});
#				$kernel->post( $self->{parent}, $self->{handle}, $gamestate );
			}
		}
	);

	return $self;
}


1; # End of App::Betting::Toolkit::Server
