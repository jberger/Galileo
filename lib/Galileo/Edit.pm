package Galileo::Edit;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON;
my $json = Mojo::JSON->new;

use Encode qw( encode_utf8 );

sub edit_page {
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

  $self->render;
}

sub store_page {
  my $self = shift;
  $self->on(message => sub {
    my ($self, $message) = @_;
    my $data = $json->decode( encode_utf8($message) );

    my $schema = $self->schema;

    unless($data->{title}) {
      $self->send('Not saved! A title is required!');
      return;
    }
    my $author = $schema->resultset('User')->single({name=>$self->session->{username}});
    $data->{author_id} = $author->id;
    $schema->resultset('Page')->update_or_create(
      $data, {key => 'pages_name'},
    );
    $self->expire('main');
    $self->send('Changes saved');
  });
}

sub edit_menu {
  my $self = shift;
  my $name = 'main';
  my $schema = $self->schema;

  my %active = 
    map { $_ => 1 } 
    @{ $json->decode(
      $schema->resultset('Menu')->single({name => $name})->list
    )};
  
  my ($active, $inactive) = ( '', '' );
  my @pages = $schema->resultset('Page')->all;
  for my $page ( @pages ) {
    next unless $page;
    my $name = $page->name;
    my $id   = $page->page_id;
    next if $name eq 'home';
    exists $active{$id} ? $active : $inactive 
      .= sprintf qq{<li id="pages-%s"><span class="label label-info">%s</span></li>\n}, $id, $page->title;
  }

  $self->title( 'Setup Main Navigation Menu' );
  $self->content_for( banner => 'Setup Main Navigation Menu' );
  $self->render(
    active   => Mojo::ByteStream->new( $active ), 
    inactive => Mojo::ByteStream->new( $inactive ),
  );
}

sub store_menu {
  my $self = shift;
  $self->on( message => sub {
    my ($self, $message) = @_;
    my $data = $json->decode($message);
    my $name = $data->{name};
    my $list = $data->{list};

    my $schema = $self->schema;
  
    my @pages = 
      map { my $page = $_; $page =~ s/^pages-//; $page}
      grep { ! /^header-/ }
      @$list;

    $schema->resultset('Menu')->update(
      {
        list => $json->encode(\@pages),
      },
      { key => $name }
    );

    $self->expire($name);
    $self->send('Changes saved');
  });
}

sub expire {
  my ($self, $name) = @_;
  $self->flex_memorize->{$name}{expires} = 1;
}

1;

