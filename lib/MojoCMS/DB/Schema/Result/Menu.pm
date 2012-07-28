package MojoCMS::DB::Schema::Result::Menu;

use DBIx::Class::Candy
  -autotable => v1;

primary_column menu_id => {
  data_type => 'integer',
  is_auto_increment => 1,
};

unique_column name => { 
  data_type => 'text'
};

column list => { 
  data_type => 'text'
};

1;

