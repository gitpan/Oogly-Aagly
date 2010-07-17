package Test::FormFu;
use Oogly::Aagly ':all';

field 'search' => {
    label => 'user search',
    error => 'your search must contain a valid id number',
    element => {
      type => 'input_checkbox',
      options => [
        { value => '100', label => 'Users' },
        { value => '101', label => 'Students' },
      ],
      default => [100,101]
    },
    validation => sub {
        my ($form, $field, $params) = @_;
        if ($field->{value}) {
            $form->error($field, $field->{error})
                if $field->{value} =~ /\D/;
        }
    }
};

1;