use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'MojoCMS',
  dist_version => '0.000_001',
  dist_author => 'Joel Berger',
  dist_abstract => 'A simple CMS using Mojolicious',
  license => 'perl',
  
  requires => {
    'Mojolicious' => 0,
    'DBD::SQLite' => 0,
    'DBIx::Class' => 0,
    'DBIx::Class::Candy' => 0,
    'SQL::Translator' => 0,
    'Term::Prompt' => 0,
  },
  configure_requires => {
    'Module::Build' => 0.38,
  },
);

$builder->create_build_script;
