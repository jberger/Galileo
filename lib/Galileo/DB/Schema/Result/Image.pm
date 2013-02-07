package Galileo::DB::Schema::Result::Image;

use DBIx::Class::Candy
  -autotable => v1;

primary_column image_id => {
  data_type => 'INT',
  is_auto_increment => 1,
};

column author_id => { 
  data_type => 'INT'
};

unique_column name => { 
  data_type => 'VARCHAR',
  size => 255,
};

column format => { 
  data_type => 'VARCHAR',
  size => 10,
};
  
column data => { 
  data_type => 'BLOB',
};

belongs_to author => 'Galileo::DB::Schema::Result::User', 'author_id';

1;

