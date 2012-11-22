package Galileo::DB::Schema::Result::User;

use DBIx::Class::Candy
  -autotable => v1,
  -components => [ qw/ EncodedColumn / ];

primary_column user_id => {
  data_type => 'INT',
  is_auto_increment => 1,
};

unique_column name => { 
  data_type => 'VARCHAR',
  size => 255,
};

column full => {
  data_type => 'TEXT',
};

column password => {
    data_type => 'CHAR',
    size      => 59,
    encode_column => 1,
    encode_class  => 'Crypt::Eksblowfish::Bcrypt',
    encode_args   => { key_nul => 0, cost => 8 },
    encode_check_method => 'check_password',
};

column is_author => { 
  data_type => 'BOOL',
  default_value => 0,
};

column is_admin => { 
  data_type => 'BOOL',
  default_value => 0,
};

has_many pages => 'Galileo::DB::Schema::Result::Page', 'author_id';

1;

