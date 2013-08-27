package Galileo::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub users { shift->render }
sub pages { shift->render }
sub user  { shift->render }

sub store_user {
  my $self = shift;
  $self->on( json => sub {
    my ($self, $data) = @_;

    my $pass1 = delete $data->{pass1};
    my $pass2 = delete $data->{pass2};
    if ( $pass1 or $pass2 ) {
      unless ( $pass1 eq $pass2 ) {
        $self->send({ json => { 
          message => 'Not saved! Passwords do not match', 
          success => \0,
        } });
        return 0;
      }
      $data->{password} = $pass1;
    }

    my $rs = $self->schema->resultset('User');
    unless ( $rs->single({ name => $data->{name} }) or $data->{password}) {
      $self->send({ json => { 
        message => 'Cannot create user without a password',
        success => \0, 
      } });
      return 0;
    }

    $data->{$_} = $data->{$_} ? 1 : 0 for ( qw/is_author is_admin/ );

    $rs->update_or_create(
      $data, {key => 'users_name'},
    );
    $self->send({ json => {
      message => 'Changes saved',
      success => \1,
    } });
  });
}

sub remove_page {
  my $self = shift;

  $self->on( json => sub {
    my ($self, $data) = @_;
    my $id = $data->{id};

    if ($id == 1) {
      $self->send({ json => {
        success => \0,
        message => 'Cannot remove home page',
      } });
      return;
    }

    my $page = $self->schema->resultset('Page')->single({ page_id => $id });

    unless ( $page ) {
      $self->send({ json => {
        success => \0,
        message => "Could not access page (id $id)",
      } });
      return;
    }

    my $affected = $page->delete;
    #TODO remove page from nav menu if present

    unless ( $affected ) {
      $self->send({ json => {
        success => \0,
        message => 'Database reports failure on deleting page',
      } });
      return;
    }

    $self->send({ json => {
      success => \1,
      message => 'Page removed',
    } });
    return;

  });
}

1;

