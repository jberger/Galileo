package MojoCMS::Page;
use Mojo::Base 'Mojolicious::Controller';

sub show {
  my $self = shift;
  my $name = $self->param('name');

  my $page = $self->schema->resultset('Page')->single({ name => $name });
  if ($page) {
    $self->render( show => page => $page );
  } else {
    if ($self->session->{username}) {
      $self->redirect_to("/edit/$name");
    } else {
      $self->render_not_found;
    }
  }
}

1;

