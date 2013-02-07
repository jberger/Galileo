package Galileo::Image;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'j';

my @gif_1x1px = (
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0xff,
  0x00, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
);

sub show {
  my $self = shift;
  my $name = $self->param('name');
  if (my $image = $self->schema->resultset('Image')->single({name=>$name})) {
    (my $format = lc($name)) =~ s/^.*\.([^\.]+)$/$1/;
    $self->render_data($image->data, format=>$format);
  }
  else {
    # image not found
    $self->render_data(pack('C*', @gif_1x1px), format=>'gif');
  }
}

sub upload {
  my $self = shift;
  my $file = $self->param('file');
  my ($format) = ($file->headers->content_type =~ m!^image/(.+)$!);
  my ($name)   = ($file->headers->content_disposition =~ m!filename="([^"]+)"!);
  if ($file->asset && $format && $name) {
    my $author = $self->schema->resultset('User')->single({name=>$self->session->{username}});
    $self->schema->resultset('Image')->update_or_create({
        author_id => $author->id,
        data      => $file->asset->slurp,
        name      => $name,
        format    => $format,
    });
    $self->render_text(j {success=>1, imagePath=>"/image/$name"});
  }
  else {
    $self->render_text(j {success=>0, message=>"Upload failed!"});
  }
}

1;

