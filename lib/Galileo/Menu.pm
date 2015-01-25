package Galileo::Menu;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'j';
use Mojo::ByteStream 'b';

sub edit {
  my $self = shift;
  my $name = 'main';
  my $schema = $self->schema;

  my @active = @{ j(
    $schema->resultset('Menu')->single({name => $name})->list
  ) };
  my %active =
    map { $_ => '' }
    @active;

  my @inactive;

  my @pages = $schema->resultset('Page')->all;
  for my $page ( @pages ) {
    next unless $page;
    my $name = $page->name;
    my $id   = $page->page_id;
    next if $name eq 'home';
    my $li = sprintf qq{<li id="pages-%s"><span class="label label-info">%s</span></li>\n}, $id, $page->title;
    if (exists $active{$id}) {
      $active{$id} = $li;
    } else {
      push @inactive, $li;
    }
  }

  $self->title( 'Setup Main Navigation Menu' );
  $self->content_for( banner => 'Setup Main Navigation Menu' );
  $self->render(
    active   => Mojo::ByteStream->new( join '', @active{@active} ),
    inactive => Mojo::ByteStream->new( join '', @inactive ),
  );
}

sub store {
  my $self = shift;
  $self->on( json => sub {
    my ($self, $data) = @_;
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
    my $content = $self->include('nav_menu') || '';
    $self->send({ json => {
      message => 'Changes saved',
      success => \1,
      content => b($content)->squish,
    } });
  });
}

1;

