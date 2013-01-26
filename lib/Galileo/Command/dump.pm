package Galileo::Command::dump;
use Mojo::Base 'Mojolicious::Command';
use File::Spec;
use Mojo::Util 'spurt';

has description => "Dump all stored pages as markdown\n";
has usage => <<END;
usage: $0 dump [directory]

An optional directory to dump to may be specified; the directory 
must exist. By default it dumps to the current working directory.
END

sub run {
  my $self = shift;
  my $dir = shift || '.';
  die "$dir does not exist" unless -d $dir;

  my $db = $self->app->schema;
  my $pages = $db->resultset('Page')->search;
  while ( my $page = $pages->next ) {
    my $file = File::Spec->catfile( $dir, $page->name . '.md' );
    spurt $page->md, $file;
  }
}

1;


