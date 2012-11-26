package Galileo::DB::Schema;
use base qw/DBIx::Class::Schema/;

our $VERSION = '1';
$VERSION = eval $VERSION;

__PACKAGE__->load_namespaces();

1;

