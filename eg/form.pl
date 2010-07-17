#!/usr/bin/perl

package form;
use Oogly::Aagly qw/:all/;

# cpan and see Oogly for all the gritty details ...
field 'search' => {
    label => 'user search',
    error => 'your search must contain a valid id number',
    element => {
        type => 'input_text'
    },
    validation => sub {
        my ($form, $field, $params) = @_;
        $form->error($field, $field->{error})
            if $field->{value} =~ /\D/;
    }
};

my $form = form->new;
print $form->render('myform', '/form/processing', 'search');