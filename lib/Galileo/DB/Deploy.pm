package Galileo::DB::Deploy;
use Moose;
BEGIN{ extends 'DBIx::Class::DeploymentHandler' }

# A wrapper class for DBICDH for use with Galileo

use Mojo::JSON 'j';;

use File::ShareDir qw/dist_dir/;
use File::Spec;
use File::Temp ();
use File::Copy::Recursive 'dircopy';

has 'temp_script_dir' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_temp_script_dir',
);

sub _build_temp_script_dir {
  File::Temp->newdir( $ENV{KEEP_TEMP_DIR} ? (CLEANUP => 0) : () );
}

has 'real_script_dir' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_real_script_dir',
);

sub _build_real_script_dir {
  my $dev_dir = File::Spec->catdir( qw/ lib Galileo files sql / );
  -e $dev_dir ? $dev_dir : File::Spec->catdir( dist_dir('Galileo'), 'sql' );
}

has 'script_directory' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_script_directory',
);

sub _build_script_directory {
  my $self = shift;
  my $dir  = $self->real_script_dir;
  my $temp = $self->temp_script_dir;
  dircopy $dir, $temp or die "Cannot copy from $dir to $temp";
  return "$temp";
}

has 'databases' => (
  is => 'rw',
  lazy => 1,
  builder => '_build_databases',
);

sub _build_databases { [ shift->schema->storage->sqlt_type ] }

has '+force_overwrite' => (
  default => 1,
);

has '+ignore_ddl' => (
  default => 1,
);

sub installed_version {
  my $self = shift;
  return eval{ $self->database_version }
}

sub setup_unversioned {
  my $self = shift;

  unless ( $self->version_storage_is_installed ) {
    $self->prepare_version_storage_install;
    $self->install_version_storage;
  }

  $self->add_database_version({ version => 1 });

  return 1;
}

sub do_install {
  my $self = shift;

  $self->prepare_install;
  $self->install;
}

sub do_upgrade {
  my $self = shift;

  $self->prepare_upgrade;
  $self->upgrade;
}

sub has_admin_user {
  my $self = shift;
  return eval { $self->schema->resultset('User')->first }
}

sub inject_sample_data {
  my $self = shift;
  my $schema = $self->schema;

  if(ref $schema->storage eq 'DBIx::Class::Storage::DBI::Pg'){
    $schema->storage->sql_maker->quote_char([ qw/" "/] );
    $schema->storage->sql_maker->name_sep('.');
  }

  my $user = shift or die "Must provide an admin username\n";
  my $pass = shift or die "Must provide a password for admin user\n";
  my $full = shift || "Administrator";

  my $admin = $schema->resultset('User')->create({
    name => $user,
    full => $full,
    password => $pass,
    is_author => 1,
    is_admin  => 1,
  });

  $schema->resultset('Page')->create({
    name      => 'home',
    title     => 'Galileo CMS',
    html      => <<'HTML',
<h2>Welcome to your Galileo CMS site!</h2>

<blockquote>
  <p>Galileo Galilei was "an Italian physicist, mathematician, astronomer, and philosopher who played a major role in the Scientific Revolution." -- <a href="https://en.wikipedia.org/wiki/Galileo_Galilei">Wikipedia</a> </p>
</blockquote>

<p>When he first turned the telescope to face Jupiter, he used modern technology to improve the world around him.</p>

<p>Like the great scientist it is named for, Galileo CMS is not afraid to be very modern. Learn more about it on the <a href="/page/about">about</a> page.</p>

<p><img src="/portrait.jpg" alt="Portrait of Galileo Galilei" title="" /></p>
HTML
    md        => <<'MARKDOWN',
##Welcome to your Galileo CMS site!

> Galileo Galilei was "an Italian physicist, mathematician, astronomer, and philosopher who played a major role in the Scientific Revolution." -- [Wikipedia](https://en.wikipedia.org/wiki/Galileo_Galilei)

When he first turned the telescope to face Jupiter, he used modern technology to improve the world around him.

Like the great scientist it is named for, Galileo CMS is not afraid to be very modern. Learn more about it on the [about](/page/about) page.

![Portrait of Galileo Galilei](/portrait.jpg)
MARKDOWN
    author_id => $admin->user_id,
  });

  my $about = $schema->resultset('Page')->create({
    name      => 'about',
    title     => 'About Galileo',
    html      => <<'HTML',
<p>Galileo CMS is built upon some great open source projects:</p>

<ul>
<li><a href="http://perl.org">Perl</a> - if you haven't looked at Perl lately, give it another try!</li>
<li><a href="http://mojolicio.us">Mojolicious</a> - a next generation web framework for the Perl programming language</li>
<li><a href="http://www.dbix-class.org/">DBIx::Class</a> - an extensible and flexible Object/Relational Mapper written in Perl</li>
<li><a href="http://code.google.com/p/pagedown/">PageDown</a> (Markdown engine) - the version of Attacklab's Showdown and WMD as used on Stack Overflow and the other Stack Exchange sites</li>
<li><a href="http://twitter.github.com/bootstrap">Bootstrap</a> - the beautiful CSS/JS library from Twitter</li>
<li><a href="http://jquery.com/">jQuery</a> - because everything uses jQuery</li>
<li><a href="http://wavded.github.com/humane-js/">HumaneJS</a> - A simple, modern, browser notification system</li>
</ul>

<p>Galileo is developed by <a href="https://github.com/jberger">Joel Berger</a>. <a href="https://github.com/jberger/Galileo">Fork it</a> on GitHub!</p>
HTML
    md        => <<'MARKDOWN',
Galileo CMS is built upon some great open source projects:

* [Perl](http://perl.org) - if you haven't looked at Perl lately, give it another try!
* [Mojolicious](http://mojolicio.us) - a next generation web framework for the Perl programming language
* [DBIx::Class](http://www.dbix-class.org/) - an extensible and flexible Object/Relational Mapper written in Perl
* [PageDown](http://code.google.com/p/pagedown/) (Markdown engine) - the version of Attacklab's Showdown and WMD as used on Stack Overflow and the other Stack Exchange sites
* [Bootstrap](http://twitter.github.com/bootstrap) - the beautiful CSS/JS library from Twitter
* [jQuery](http://jquery.com/) - because everything uses jQuery
* [HumaneJS](http://wavded.github.com/humane-js/) - A simple, modern, browser notification system

Galileo is developed by [Joel Berger](https://github.com/jberger). [Fork it](https://github.com/jberger/Galileo) on GitHub!
MARKDOWN
    author_id => $admin->user_id,
  });

  $schema->resultset('Menu')->create({
    name => 'main',
    list => j( [ $about->page_id ] ),
  });

}

sub create_test_object {
  my $class = shift;
  my $opts = ref $_[-1] eq 'HASH' ? pop : {};

  require Galileo;
  require Galileo::DB::Schema;

  my $db = Galileo::DB::Schema->connect('dbi:SQLite:dbname=:memory:','','',{sqlite_unicode=>1});

  my $dh = __PACKAGE__->new(
    databases => [],
    schema => $db,
  );
  $dh->do_install;
  $dh->inject_sample_data('admin', 'pass', 'Joe Admin');


  if ($opts->{test}) {
    require Test::More;
    Test::More::ok(
      $db->resultset('User')->single({name => 'admin'})->check_password('pass'),
      'DB user checks out'
    );
    Test::More::ok( $dh->installed_version, 'Found version information' );
  }

  require Test::Mojo;
  my $t = Test::Mojo->new(Galileo->new(db => $db));

  return wantarray ? ($t, $dh) : $t;
}

1;

