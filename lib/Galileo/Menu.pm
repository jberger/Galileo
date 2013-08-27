package Galileo::Menu;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'j';

sub edit {
  my $self = shift;
  my $name = 'main';
  my $schema = $self->schema;

  my %active = 
    map { $_ => 1 } 
    @{ j(
      $schema->resultset('Menu')->single({name => $name})->list
    ) };
  
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

sub store {
  my $self = shift;
  $self->on( text => sub {
    my ($self, $message) = @_;
    my $data = j($message);
    my $name = $data->{name};
    my $list = $data->{list};

    my $schema = $self->schema;
  
    my @pages = 
      map { my $page = $_; $page =~ s/^pages-//; $page}
      grep { ! /^header-/ }
      @$list;

    $schema->resultset('Menu')->update(
      {
        list => j(\@pages),
      },
      { key => $name }
    );

    $self->memorize->expire($name);
    $self->send({ text => j({
      message => 'Changes saved',
      success => \1,
    }) });
  });
}

1;

