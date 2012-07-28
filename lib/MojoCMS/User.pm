package MojoCMS::User;
use Mojo::Base 'Mojolicious::Controller';

sub login {
  my $self = shift;
  my $name = $self->param('username');
  my $pass = $self->param('password');
  my $from = $self->param('from');

  my $schema = $self->schema;

  my $user = $schema->resultset('User')->single({name => $name});
  if ($user and $user->check_password($pass)) {
    $self->flash( onload_message => "Welcome Back!" );
    $self->session->{id} = $user->user_id;
    $self->session->{username} = $name;
  } else {
    $self->flash( onload_message => "Sorry try again" );
  }
  $self->redirect_to( $from );
}

sub logout {
  my $self = shift;
  $self->session( expires => 1 );
  $self->redirect_to( $self->home_page );
}

1;

