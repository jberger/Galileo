package Galileo::File;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'j';
use File::Next;
use File::Spec;

sub list {
  my $self = shift;
  my $dir = $self->app->config->{files}[0];

  my $iter;
  if ( -d $dir ) {
    $iter = File::Next::files( $dir );
  }

  $self->on( text => sub {
    my ($ws, $text) = @_;
    my $data = j $text;
    my $list = _get_list( $iter, $dir, $data->{limit} );
    $ws->send({ text => j( $list ) });
  });
}

sub _get_list {
  my ($iter, $dir, $limit) = @_;

  unless ( defined $iter ) {
    return {files => [], finished => \1};
  }

  $limit ||= 20;

  my @files;
  my $finished = \0;

  while ( 1 ) {
    last unless $limit--;

    my $file = $iter->();
    unless (defined $file) {
      $finished = \1;
      last;
    }

    push @files, $file;
  }

  return { files => \@files, finished => $finished };
}

1;

