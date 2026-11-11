package PerlSchool::Schema::Result::Erratum;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('errata');
__PACKAGE__->add_columns(
  id => { data_type => 'integer', is_auto_increment => 1 },
  book_id => { data_type => 'integer', is_foreign_key => 1 },
  date_reported => { data_type => 'date', default_value => \q{CURRENT_DATE} },
  status => { data_type => 'text', default_value => 'Reported' },
  description => { data_type => 'text' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(
  book => 'PerlSchool::Schema::Result::Book',
  { 'foreign.id' => 'self.book_id' },
);

1;
