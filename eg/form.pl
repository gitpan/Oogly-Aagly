#!/usr/bin/perl
use strict;
use warnings;

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
        if ($field->{value}) {
            $form->error($field, $field->{error})
                if $field->{value} =~ /\D/;
        }
    }
};

field 'login' => {
    label => 'user login',
    required => 1,
    element => {
        type => 'input_text'
    }
};

field 'password' => {
    label => 'user password',
    element => {
        type => 'input_password'
    }
};

my $form = form->new;
   $form->validate(qw/search login password/);

print join "\n", $form->render_control(qw/search login password/);
#print      "\n";
#print join "\n", @{$form->errors};
#print $form->render('myform', '/form/processing', 'search');