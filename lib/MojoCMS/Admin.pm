package MojoCMS::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub users { shift->render }

sub pages { shift->render }

1;

