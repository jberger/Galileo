package MojoCMS::DB::Schema::Result::User;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('users');
__PACKAGE__->add_columns(
  userid => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  name => { data_type => 'text' },
  pass => { data_type => 'text' },
  is_author => { 
    data_type => 'integer',
    default_value => 0,
  },
  is_admin => { 
    data_type => 'integer',
    default_value => 0,
  },
);
__PACKAGE__->set_primary_key('userid');
__PACKAGE__->has_many( pages => 'MojoCMS::DB::Schema::Result::Page', 'userid');

1;

