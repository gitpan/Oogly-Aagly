#!/usr/bin/perl
# ABSTRACT: Get Oogly-Aagly Templates

use warnings;
use strict;

package goat;
use Oogly::Aagly ();
use File::ShareDir ':ALL';
use File::Copy;
use Cwd;

=method copy_templates

The copy_templates method utilizied by goat.pl (get Oogly-Aagly Templates), 
will copy the default form element templates stored in the main Perl library, 
to the current working directory.

=cut

sub copy_templates {
    my $to   = Cwd::getcwd();
    my $from = module_dir('Oogly::Aagly') . "/elements";
    for (qw/
         form
         input_checkbox
         input_file
         input_hidden
         input_password
         input_radio
         input_text
         select
         select_multiple
         textarea/) {
        copy("$from/$_.tt","$to/$_.tt") or
            die "Oogly-Aagly failed copying html templates: $from/$_.tt to $to/$_.tt, $!";
    }
    print
        "Oogly-Aagly copied html templates to $to\n";
}

# copy standard template to the cwd
copy_templates;

1;