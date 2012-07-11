package MojoCMS::DB::Schema::Result::Page;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('pages');
__PACKAGE__->add_columns( 
  id => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  author_id => { data_type => 'integer' },
  name => { data_type => 'text' },
  title => { data_type => 'text' },
  html => { data_type => 'text' },
  md => { data_type => 'text' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint( page_name => ['name'] );
__PACKAGE__->belongs_to( user => 'MojoCMS::DB::Schema::Result::User', 'id' );

1;

