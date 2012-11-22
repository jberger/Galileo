package Galileo::DB::Schema::Result::Page;

use DBIx::Class::Candy
  -autotable => v1;

primary_column page_id => {
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
  
column title => { 
  data_type => 'TEXT',
};

column html => {
  data_type => 'TEXT',
};

column md => { 
  data_type => 'TEXT',
};

belongs_to author => 'Galileo::DB::Schema::Result::User', 'author_id';

1;

