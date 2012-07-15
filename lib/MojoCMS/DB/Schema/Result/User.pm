package MojoCMS::DB::Schema::Result::User;

use DBIx::Class::Candy
  -autotable => v1;

primary_column id => {
  data_type => 'integer',
  is_auto_increment => 1,
};

column name => { 
  data_type => 'text'
};

column pass => { 
  data_type => 'text'
};

column is_author => { 
  data_type => 'integer',
  default_value => 0,
};

column is_admin => { 
  data_type => 'integer',
  default_value => 0,
};

has_many pages => 'MojoCMS::DB::Schema::Result::Page', 'author_id';

1;

