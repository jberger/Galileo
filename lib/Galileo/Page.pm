package Galileo::Page;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'j';

sub show {
  my $self = shift;
  my $name = $self->param('name');

  my $page = $self->schema->resultset('Page')->single({ name => $name });
  if ($page) {
    $self->render( page => $page );
  } else {
    if ( $self->is_author ) {
      $self->redirect_to(edit_page => name => $name);
    } else {
      $self->reply->not_found;
    }
  }
}

sub edit {
  my $self = shift;
  my $name = $self->param('name');
  $self->title( "Editing Page: $name" );
  $self->content_for( banner => "Editing Page: $name" );

  my $schema = $self->schema;

  my $page = $schema->resultset('Page')->single({name => $name});
  if ($page) {
    my $title = $page->title;
    $self->stash( title_value => $title );
    $self->stash( input => $page->md );
  } else {
    $self->stash( title_value => '' );
    $self->stash( input => "Hello World" );
  }

  $self->stash(
    sanitize               => $self->config->{sanitize} // 1, #/# highlight fix
    pagedown_extra_options => j( $self->config->{pagedown_extra_options} ),
  );

  $self->render;
}

sub store {
  my $self = shift;
  $self->on( json => sub {
    my ($self, $data) = @_;

    my $schema = $self->schema;

    unless ( $data->{title} ) {
      $self->send({ json => {
        message => 'Not saved! A title is required!',
        success => \0,
      } });
      return;
    }

    my $author = $schema->resultset('User')->single({name=>$self->session->{username}});
    $data->{author_id} = $author->id;
    $schema->resultset('Page')->update_or_create(
      $data, {key => 'pages_name'},
    );
    $self->memorize->expire('main');
    $self->send({ json => {
      message => 'Changes saved',
      success => \1,
    } });
  });
}

1;

