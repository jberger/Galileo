package Galileo::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub users { shift->render }
sub pages { shift->render }
sub user { shift->render }

sub store_user {
  my $self = shift;
  $self->on( message => sub {
    my ($self, $message) = @_;
    my $data = Mojo::JSON->new->decode($message);

    my $pass1 = delete $data->{pass1};
    my $pass2 = delete $data->{pass2};
    if ( $pass1 or $pass2 ) {
      unless ( $pass1 eq $pass2 ) {
        $self->send( 'Not saved! Passwords do not match' );
        return 0;
      }
      $data->{password} = $pass1;
    }

    my $rs = $self->schema->resultset('User');
    unless ( $rs->single({ name => $data->{name} }) or $data->{password}) {
      $self->send( 'Cannot create user without a password' );
      return 0;
    }

    $data->{$_} = $data->{$_} ? 1 : 0 for ( qw/is_author is_admin/ );

    $rs->update_or_create(
      $data, {key => 'users_name'},
    );
    $self->send('Changes saved');
  });
}

1;

