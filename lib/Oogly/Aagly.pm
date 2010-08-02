package Oogly::Aagly;
BEGIN {
  $Oogly::Aagly::VERSION = '0.03';
}
# ABSTRACT: A form building, processing and data validation system!

use strict;
use warnings;
use 5.008001;
use File::ShareDir ':ALL';
use Template;
use Template::Stash;
use base 'Oogly';
use Data::Dumper;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Indent = 0;

BEGIN {
    use Exporter();
    use vars qw( @ISA %EXPORT_TAGS @EXPORT_OK );
    @ISA    = qw( Exporter );
    @EXPORT_OK = qw(
        new
        setup
        field
        mixin
        error
        errors
        check_field
        check_mixin
        validate
        use_mixin
        use_mixin_field
        basic_validate
        basic_filter
        Oogly
        render
        templates
        template
        tdir
    );
    %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );
}

{
    no warnings 'redefine';
    sub new { return Oogly::new(@_); }
    sub setup { return Oogly::setup(@_); }
    sub field { return Oogly::field(@_); }
    sub mixin { return Oogly::mixin(@_); }
    sub error { return Oogly::error(@_); }
    sub errors { return Oogly::errors(@_); }
    sub check_field { return Oogly::check_field(@_); }
    sub check_mixin { return Oogly::check_mixin(@_); }
    sub validate { return Oogly::validate(@_); }
    sub use_mixin { return Oogly::use_mixin(@_); }
    sub use_mixin_field { return Oogly::use_mixin_field(@_); }
    sub basic_validate { return Oogly::basic_validate(@_); }
    sub basic_filter { return Oogly::basic_filter(@_); }
    sub Oogly { return Oogly::Oogly(@_); }
}


{
    no warnings 'redefine';
    sub Oogly::setup {
        my $class = shift;
        my $params = shift;
        my $self  = {};
        bless $self, $class;
        my $flds = $Oogly::FIELDS;
        my $mixs = $Oogly::MIXINS;
        $self->{params} = $params;
        $self->{fields} = $flds;
        $self->{mixins} = $mixs;
        $self->{errors} = [];
        $self->{templates}  = {
            directory       => module_dir('Oogly::Aagly') . "/elements/",
            form            => "form.tt",
            input_checkbox   => "input_checkbox.tt",
            input_file      => "input_file.tt",
            input_hidden    => "input_hidden.tt",
            input_password  => "input_password.tt",
            input_radio     => "input_radio.tt",
            input_text      => "input_text.tt",
            select          => "select.tt",
            select_multiple => "select_multiple.tt",
            textarea        => "textarea.tt",
        };
        
        # debugging - print Dumper($FIELDS); exit;
        
        # depreciated: 
        # die "No valid parameters were found, parameters are required for validation"
        #     unless $self->{params} && ref($self->{params}) eq "HASH";
        
        # validate mixin directives
        foreach (keys %{$self->{mixins}}) {
            $self->check_mixin($_, $self->{mixins}->{$_});
        }
        # validate field directives
        foreach (keys %{$self->{fields}}) {
            $self->check_field($_, $self->{fields}->{$_}) unless $_ eq 'errors';
        }
        # check for and process a mixin directive
        foreach (keys %{$self->{fields}}) {
            unless ($_ eq 'errors') {
                $self->use_mixin($_, $self->{fields}->{$_}->{mixin})
                    if $self->{fields}->{$_}->{mixin};
            }
        }
        # check for and process a mixin_field directive
        foreach (keys %{$self->{fields}}) {
            unless ($_ eq 'errors') {
                $self->use_mixin_field($self->{fields}->{$_}->{mixin_field}, $_)
                    if $self->{fields}->{$_}->{mixin_field}
                    && $self->{fields}->{$self->{fields}->{$_}->{mixin_field}};
            }
        }
        # check for and process input filters
        foreach (keys %{$self->{fields}}) {
            unless ($_ eq 'errors') {
                my $filters = [];
                if (defined $self->{fields}->{$_}->{filters}) {
                    $filters = $self->{fields}->{$_}->{filters};
                }
                if (defined $self->{fields}->{$_}->{filter}) {
                    $filters = $self->{fields}->{$_}->{filter};
                }
                $filters = [$filters] unless ref($filters) eq "ARRAY";
                foreach my $filter (@{$filters}) {
                    if (defined $self->{params}->{$_}) {
                        $self->basic_filter($filter, $_);
                    }
                }
            }
        }
        return $self;
    }
}

{
    no warnings 'redefine';
    sub Oogly::check_mixin {
        my ($self, $mixin, $spec) = @_;
        
        my $directives = {
            required    => sub {1},
            min_length  => sub {1},
            max_length  => sub {1},
            data_type   => sub {1},
            ref_type    => sub {1},
            regex       => sub {1},
            element     => sub {1},
            
            filter      => sub {1},
            filters     => sub {1},
            
        };
        
        foreach (keys %{$spec}) {
            if (!defined $directives->{$_}) {
                die "The `$_` directive supplied by the `$mixin` mixin is not supported";
            }
            if (!$directives->{$_}->()) {
                die "The `$_` directive supplied by the `$mixin` mixin is invalid";
            }
        }
        
        return 1;
    }
}

{
    no warnings 'redefine';
    sub Oogly::check_field {
        my ($self, $field, $spec) = @_;
        
        my $directives = {
            mixin       => sub {1},
            mixin_field => sub {1},
            validation  => sub {1},
            errors      => sub {1},
            label       => sub {1},
            error       => sub {1},
            value       => sub {1},
            name        => sub {1},
            filter      => sub {1},
            filters     => sub {1},
            element     => sub {1},
            
            required    => sub {1},
            min_length  => sub {1},
            max_length  => sub {1},
            data_type   => sub {1},
            ref_type    => sub {1},
            regex       => sub {1},
        };
        
        foreach (keys %{$spec}) {
            if (!defined $directives->{$_}) {
                die "The `$_` directive supplied by the `$field` field is not supported";
            }
            if (!$directives->{$_}->()) {
                die "The `$_` directive supplied by the `$field` field is invalid";
            }
        }
        
        return 1;
    }
}

{
    no warnings 'redefine';
    sub Oogly::Oogly {
        my $PACKAGE = $Oogly::PACKAGE;
        my %properties = @_;
        my $KEY  = undef;
           $KEY .= (@{['A'..'Z',0..9]}[rand(36)]) for (1..5);
        $PACKAGE = "Oogly::Aagly::Instance::" . $KEY;
        
        my $code = "package $PACKAGE; use Oogly::Aagly ':all'; our \$PACKAGE = '$PACKAGE'; ";
        $code .= "our \$FIELDS  = \$PACKAGE::fields = {}; ";
        $code .= "our \$MIXINS  = \$PACKAGE::mixins = {}; ";
        
        while (my($key, $value) = each(%properties)) {
            die "$key is not a supported property"
                unless $key eq 'mixins' || $key eq 'fields';
            if ($key eq 'mixins') {
                while (my($key, $value) = each(%{$properties{mixins}})) {
                    $code .= "mixin('" . $key . "'," . Dumper($value) . ");";
                }
            }
            if ($key eq 'fields') {
                while (my($key, $value) = each(%{$properties{fields}})) {
                    $code .= "field('" . $key . "'," . Dumper($value) . ");";
                }
            }
        } $code .= "1;";
        
        eval $code or die $@;
        return $PACKAGE;
    }
}


sub render {
    my ($self, $name, $url, @fields) = @_;
    my $counter = 0;
    my @form_parts = ();
    foreach my $field (@fields) {
        $self->check_field($field);
        die "The field `$field` does not have an element directive"
            unless defined $self->{fields}->{$field}->{element};
        my $template = Template->new(
            INTERPOLATE => 1,
	    EVAL_PERL   => 1,
	    ABSOLUTE    => 1,
	    ANYCASE     => 1
        );
        my $type = $self->{fields}->{$field}->{element}->{type};
        my $html = $self->tdir($self->{templates}->{$type});
           $html = $self->tdir($self->{fields}->{$field}->{element}->{template})
            if defined $self->{fields}->{$field}->{element}->{template};
        my $tvars = $self->{fields}->{$field};
           $tvars->{name} = $field;
        my $args = {
            name    => $name,
            url     => $url,
            form    => $self,
            field   => $tvars,
            this    => $field
        };
        $form_parts[$counter] = '';
        $template->process($html, $args, \$form_parts[$counter]);
        $counter++;
    }
    my $template = Template->new(
	INTERPOLATE => 1,
        EVAL_PERL   => 1,
        ABSOLUTE    => 1,
        ANYCASE     => 1
    );
    my $html = $self->tdir($self->{templates}->{form});
    my $args = {
        name => $name,
        url => $url,
        form => $self,
        content => join("\n", @form_parts)
    };
    my $content;
    
    $template->process($html, $args, \$content);
    return $content;
}


sub templates {
    my ($self, $path) = @_;
    return $self->{templates}->{directory} = $path;
}


sub template {
    my ($self, $element, $path) = @_;
    return $self->{templates}->{$element} = $path;
}

# The tdir method concatenates a file with the template directory and returns an absolute path
sub tdir {
    my $self = shift;
    my $file = shift;
    my $dir = $self->{templates}->{directory};
    $dir  =~ s/[\\\/]+$//;
    $file =~ s/^[\\\/]+//;
    return "$dir/$file";
}

# The dynamic Template::Stash::LIST_OPS has method adds a 'find-in-array'
# virtual list method for Template-Toolkit
$Template::Stash::LIST_OPS->{ has } = sub {
    my ($list, $value) = @_;
    return (grep /$value/, @$list) ? 1 : 0;
};


1; # End of Oogly::Aagly

__END__
=pod

=head1 NAME

Oogly::Aagly - A form building, processing and data validation system!

=head1 VERSION

version 0.03

=head1 SYNOPSIS

Oogly-Aagly is basically form building on top of the Oogly data validation
framework. This means that existing packages and code using Oogly can be easily
converted to utilize this new functionality.

The following is an example of that...

    use MyApp::FormFu;
    my $form = MyApp::FormFu->new(\%params);
    my @flds = qw/search/;
    if ($form->validate(@flds)){
        ...
    }
    else {
	print $form->render('form_name', '/url', @flds);
    }

    package MyApp::FormFu;
    use Oogly::Aagly;

    # cpan and see Oogly for all the gritty details ...
    field 'search' => {
        label => 'user search',
        error => 'your search must contain a valid id number',
	element => {
	    type => 'input',
	    template => ''
	},
        validation => sub {
            my ($form, $field, $params) = @_;
            $form->error($field, $field->{error})
                if $field->{value} =~ /\D/;
        }
    };

=head1 METHODS

=head2 render

The render method returns an html form using the supplied url, and fields.

=head2 templates

The templates method is used to define the absolute path to where the form
element templates are stored.

    $form->templates('/var/www/templates/');

=head2 template

The template method is used to define the relative path to where the specified
form element template is stored.

    $form->template(input => 'elements/input_text.tt');

=head2 Warning!

Oogly-Aagly is still undergoing testing, etc. The package is being published as
a proof-of-concept sort-a-thing. Use at your own risk, although I am confident
you'll love the simplicity, syntax and DRY nature.

=head2 Building Forms

Ok really quickly, the idea behind Oogly-Aagly (derived from Oogly) is to define
each piece of incoming data individually for DRY (dont repeat yourself) purposes.
It stands-to-reason that you'll need to use/create a form element or validate the
same data input more than once in an application of any complexity, that said,
say your application (and probably your database) has a email field, chances are
the validation rules, form element look and feel, etc, are the same each time you
request it from the user, so it makes sense to define it only once and call it
when we need it, this is the where Oogly/Oogly-Aagly concept of fields come in.
Anyway...

    package Foo;
    use Oogly::Aagly ':all';
    
    field 'email' => {
        'label' => 'Email address',
        'error' => 'Please use a valid email address',
        'element' => {
            type => 'input_text',
        },
        validation => sub {
            return $_[1]->{value} =~ /\@/ if $_[1]->{value};
        }
    };
    
    my $form = Foo->new($params_hashref);
    $form->render('form_name', 'url', 'email');

In the code above we have labeled the input parameter, given it a label,
specified which type of html form element should represent it when called, and
defined a simple validation rule to validate input.

If you are used to using Oogly the only difference you'll notice s the existence 
of the `element` hashref. This key is used to defined all form element related
options.

Forms are rendered using HTML Templates marked-up using Template-Toolkit syntax
and are stored in the Perl library. The `goat.pl` (Get Oogly-Aagly Template)
utility can be used to copy those templates to the current work directory for
customization. Oogly-Aagly only has templates for HTML form input elements, the
following is a guide to each element and how it might be defined.

=head3 Form Templates

=item form

    ... form.tt
    This template is a wrapper that encapsulates the selected form elements
    rendered.

=item input_checkbox

    ... input_checkbox
    
    field 'languages' => {
        element => {
            type => 'input_checkbox',
            options => {
                { value => 100, label => 'English' },
                { value => 101, label => 'Spanish' },
                { value => 102, label => 'Russian' },
            }
        },
        default => 100
    };
    
    ... or ...
    
    field 'languages' => {
        label => 'US Languages',
        element => {
            type => 'input_checkbox',
            options => {
                { value => 100, label => 'English' },
                { value => 101, label => 'Spanish' },
                { value => 102, label => 'Russian' },
            }
        },
        default => [100,101]
    };

=item input_file

    ... input_file
    
    field 'avatar_upload' => {
        element => {
            type => 'input_file'
        }
    };

=item input_hidden

    ... input_hidden
    
    field 'sid' => {
        element => {
            type => 'input_hidden'
        },
        value => $COOKIE{SID} # or whatever
    };

=item input_password

    ... input_password
    
    field 'password_confirm' => {
        element => {
            type => 'input_password'
        }
    };

=item input_radio

    ... input_radio
    
    field 'payment_method' => {
        element => {
            type => 'input_radio',
            options => {
                { value => 100, label => 'Visa' },
                { value => 101, label => 'MasterCard' },
                { value => 102, label => 'Discover' },
            },
            default => 100
        }
    };

=item input_text

    ... input_text
    
    field 'login' => {
        element => {
            type => 'input_login'
        }
    };

=item select

    ... select
    
    field 'payment_terms' => {
        element => {
            type => 'select',
            options => {
                { value => 100, label => 'Net 10' },
                { value => 101, label => 'Net 15' },
                { value => 102, label => 'Net 30' },
            },
        }
    };

=item select_multiple

    ... select_multiple
    
    field 'user_access_group' => {
        element => {
            type => 'select_multiple',
            options => {
                { value => 100, label => 'User' },
                { value => 101, label => 'Admin' },
                { value => 102, label => 'Super Admin' },
            },
        }
    };

=item textarea

    ... textarea
    
    field 'myprofile_greeting' => {
        element => {
            type => 'textarea',
        }
    };

=head2 Validating Forms

Validating forms is the point, simply pass and array list of field names to the
validate method in the order in which you would like them validated and presto.

    package Foo;
    use Oogly::Aagly ':all';
    
    field 'email' => {
        'label' => 'Email address',
        'error' => 'Please use a valid email address',
        'element' => {
            type => 'input_text',
        },
        validation => sub {
            return $_[1]->{value} =~ /\@/ if $_[1]->{value};
        }
    };
    
    my $form = Foo->new($params_hashref);
    
    if ($form->validate(@form_fields)) {
        # redirect ...
    }
    else {
        print $form->render('form_name', 'url', @form_fields);
    }

=head2 Customizing Forms

Included with this package is a command-line utility, `goat.pl`, which should
be used to copy Oogly-Aagly templates from the Perl library to your
current-working-directory, once there you can specify that using the template
method and customize your html elements any way you see fit.

    my $form = Foo->new($params);
    $form->templates('/var/www/view/elements');

You can expand the Oogly-Aagly template library using the template method to
add custom templates.

    my $form = Foo->new($params);
    $form->template('input_jstree' => '/var/www/view/elements/input_jstree.tt');

More to come, try it for yourself...

=head1 AUTHOR

  Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

