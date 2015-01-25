package Galileo::Command::dump;
use Mojo::Base 'Mojolicious::Command';
use File::Spec;
use Mojo::Util qw/encode spurt/;
use Getopt::Long qw/GetOptionsFromArray/;

has description => "Dump all stored pages as markdown\n";
has usage => <<END;
usage: $0 dump [options]
options:

--directory,-d
  An optional directory to dump to may be specified; the directory
  must exist. By default it dumps to the current working directory.

--title,-t
  By default the title of the page is included as an HTML comment.
  This option accepts an sprintf format for including the title.
  As a special case, if this flag is given without argument, an h1
  title is created.

--encoding,-e
  An encoding type. Defaults to UTF-8. Available encodings are the
  same as Encode module of Perl.
END

sub run {
  my $self = shift;

  GetOptionsFromArray( \@_,
    'directory=s' => \my $dir,
    'title:s'     => \(my $title = '<!-- %s -->'),
    'encoding:s'  => \(my $encoding = 'UTF-8'),
  );

  $title = '# %s' unless $title;
  if ( $dir and ! -d $dir ) {
    die qq{Directory "$dir" does not exist\n};
  }

  my $pages = $self->app->schema->resultset('Page')->search;
  while ( my $page = $pages->next ) {
    my $file = $page->name . '.md';
    $file = File::Spec->catfile( $dir, $file ) if $dir;

    my $content = sprintf "$title\n", $page->title;
    $content .= $page->md;
    $content = encode($encoding, $content) if $encoding;
    spurt $content, $file;
  }

  say "Export Complete";
}

1;


