package Mojolicious::Command::create_database;
use Mojo::Base 'Mojolicious::Command';

use Term::Prompt qw/prompt/;

has description => "Create the database for your MojoCMS application.\n";
has usage       => "usage: $0 create_database [username]\n";

use Mojo::JSON;
my $json = Mojo::JSON->new();

sub run {
  my ($self) = @_;

  my $user = prompt('x', 'Admin Username: ', '', 'admin');
  my $pass1 = prompt('p', 'Admin Password: ', '', '');
  print "\n";

  #TODO check for acceptable password

  my $pass2 = prompt('p', 'Repeat Admin Password: ', '', '');
  print "\n";

  unless ($pass1 eq $pass2) {
    die "Passwords do not match";
  }

  my $schema = $self->app->db_connect;
  $schema->deploy;

  my $admin = $schema->resultset('User')->create({
    name => $user,
    password => $pass1,
    is_author => 1,
    is_admin  => 1,
  });

  $schema->resultset('Page')->create({
    name      => 'home',
    title     => 'Home Page',
    html      => '<p>Welcome to the site!</p>',
    md        => 'Welcome to the site!',
    author_id => $admin->id,
  });

  my $about = $schema->resultset('Page')->create({
    name      => 'about',
    title     => 'About Me',
    html      => '<p>Some really cool stuff about me</p>',
    md        => 'Some really cool stuff about me',
    author_id => $admin->id,
  });

  $schema->resultset('Menu')->create({
    name => 'main',
    list => $json->encode( [ $about->id ] ), 
    html => sprintf( '<li><a href="/pages/%s">%s</a></li>', $about->name, $about->title ),
  });
}

1;
