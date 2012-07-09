package MojoCMS::DB::Schema::Result::User;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('users');
__PACKAGE__->add_columns( qw/ userid name pass is_author is_administrator / );
__PACKAGE__->set_primary_key('userid');
__PACKAGE__->has_many( pages => 'MyDB::Schema::Result::Page');

1;

