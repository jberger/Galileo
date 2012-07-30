use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'Galileo',
  dist_author => 'Joel Berger',
  license => 'perl',
  
  requires => {
    'Mojolicious' => 0,
    'DBD::SQLite' => 0,
    'DBIx::Class' => 0,
    'DBIx::Class::Candy' => 0,
    'DBIx::Class::EncodedColumn' => 0,
    'Crypt::Eksblowfish::Bcrypt' => 0,
    'SQL::Translator' => 0,
    'Term::Prompt' => 0,
  },
  configure_requires => {
    'Module::Build' => 0.38,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/Galileo",
      bugtracker => "http://github.com/jberger/Galileo/issues",
    },
  }
);

$builder->create_build_script;

