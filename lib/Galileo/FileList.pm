package Galileo::FileList;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'j';
use File::Next 'files';

sub send_list {
  my $self = shift;
  my $dir = $self->app->config->{files}[0];

  unless ( -d $dir ) {
    $self->send( text => j({files => [], finished => \1}) );
    return;
  }

  my $iter = files( $dir );

  $self->on( text => sub {
    my ($ws, $text) = @_;
    my $data = j $text;
    my $list = $self->get_list( $iter, $data->{limit} );
    $self->send( text => j( $list ) );
  });
}

sub get_list {
  my ($self, $iter, $limit) = @_;
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

