package MojoCMS::DB::Schema::Result::Page;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('pages');
__PACKAGE__->add_columns( qw/ pageid name / );
__PACKAGE__->set_primary_key('pageid');
__PACKAGE__->has_many( pages => 'MyDB::Schema::Result::Page' );
__PACKAGE__->belongs_to( user => 'MyDB::Schema::User', 'userid' );

1;

