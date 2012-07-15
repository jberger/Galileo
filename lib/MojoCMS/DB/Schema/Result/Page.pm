package MojoCMS::DB::Schema::Result::Page;

use DBIx::Class::Candy
  -autotable => v1;

primary_column id => {
  data_type => 'integer',
  is_auto_increment => 1,
};

column author_id => { 
  data_type => 'integer'
};

unique_column name => { 
  data_type => 'text'
};
  
column title => { 
  data_type => 'text'
};

column html => {
  data_type => 'text'
};

column md => { 
  data_type => 'text'
};

belongs_to user => 'MojoCMS::DB::Schema::Result::User', 'id';

1;

