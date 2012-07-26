package MojoCMS::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub users {
  my $self = shift;
  $self->render('users');
}

1;

