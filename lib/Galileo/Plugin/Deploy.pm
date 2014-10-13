package Galileo::Plugin::Deploy;

use Mojo::Base 'Mojolicious::Plugin';

use Galileo::DB::Deploy;

sub register {
  my ($plugin, $app) = @_;

  my $dh = Galileo::DB::Deploy->new( schema => $app->schema );
  $app->helper( dh => sub { $dh } );

  return $dh;
}

1;

