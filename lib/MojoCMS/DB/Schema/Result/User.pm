package MojoCMS::DB::Schema::Result::User;

use DBIx::Class::Candy
  -autotable => v1,
  -components => [ qw/ EncodedColumn / ];

primary_column id => {
  data_type => 'integer',
  is_auto_increment => 1,
};

unique_column name => { 
  data_type => 'text'
};

column password => {
    data_type => 'text',
    encode_column => 1,
    encode_class  => 'Crypt::Eksblowfish::Bcrypt',
    encode_check_method => 'check_password',
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

