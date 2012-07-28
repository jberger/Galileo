package MojoCMS::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub users {
  my $self = shift;
  $self->render('users');
}

sub pages {
  my $self = shift;
  $self->render('pages');
}

1;

