package MojoCMS::Page;
use Mojo::Base 'Mojolicious::Controller';

sub show_page {
  my $self = shift;
  my $name = $self->param('name');
  my $schema = $self->schema;

  my $page = $schema->resultset('Page')->single({ name => $name });
  if ($page) {
    my $title = $page->title;
    $self->title( $title );
    $self->content_for( banner => $title );
    $self->render( pages => page_contents => $page->html );
  } else {
    if ($self->session->{username}) {
      $self->redirect_to("/edit/$name");
    } else {
      $self->render_not_found;
    }
  }
}

1;

