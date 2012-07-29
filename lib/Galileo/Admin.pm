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
        $self->send( 'Not Updated: Passwords do not match' );
        return 0;
      }
      $data->{password} = $pass1;
    }

    $self->schema->resultset('User')->update_or_create(
      $data, {key => 'users_name'},
    );
    $self->send('Changes saved');
  });
}

1;

