package Galileo::Command::create_database;
use Mojo::Base 'Mojolicious::Command';

use Term::Prompt qw/prompt/;

has description => "Create the database for your Galileo CMS application.\n";
has usage       => "usage: $0 create_database\n";

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

  $self->inject_sample_data($user, $pass1);
}

sub inject_sample_data {
  my $self = shift;
  my $user = shift or die "Must provide an administrative username";
  my $pass = shift or die "Must provide a password for $user";
  my $schema = shift || $self->app->schema;

  $schema->deploy;

  my $admin = $schema->resultset('User')->create({
    name => $user,
    password => $pass,
    is_author => 1,
    is_admin  => 1,
  });

  $schema->resultset('Page')->create({
    name      => 'home',
    title     => 'Home Page',
    html      => '<p>Welcome to the site!</p>',
    md        => 'Welcome to the site!',
    author_id => $admin->user_id,
  });

  my $about = $schema->resultset('Page')->create({
    name      => 'about',
    title     => 'About Me',
    html      => '<p>Some really cool stuff about me</p>',
    md        => 'Some really cool stuff about me',
    author_id => $admin->user_id,
  });

  $schema->resultset('Menu')->create({
    name => 'main',
    list => $json->encode( [ $about->page_id ] ), 
  });

  return $schema;
}

1;
