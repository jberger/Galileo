package MojoCMS::DB::Schema::Result::Page;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('pages');
__PACKAGE__->add_columns( 
  pageid => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  userid => { data_type => 'integer' },
  name => { data_type => 'text' },
  title => { data_type => 'text' },
  html => { data_type => 'text' },
  md => { data_type => 'text' },
);
__PACKAGE__->set_primary_key('pageid');
__PACKAGE__->belongs_to( user => 'MojoCMS::DB::Schema::Result::User', 'userid' );

1;

