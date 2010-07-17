package Oogly::Aagly;
BEGIN {
  $Oogly::Aagly::VERSION = '0.02';
}
# ABSTRACT: A form building, processing and data validation system!

use strict;
use warnings;
use 5.008001;
use File::ShareDir ':ALL';
use Template;
use Template::Stash;
use Data::Dumper;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Indent = 0;

BEGIN {
    use Exporter();
    use vars qw( @ISA %EXPORT_TAGS @EXPORT_OK );
    @ISA    = qw( Exporter );
    @EXPORT_OK = qw(
        new
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
        template
        templates
        tdir
    );
    %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );
}


our $PACKAGE = (caller)[0];
our $FIELDS  = $PACKAGE::fields = {};
our $MIXINS  = $PACKAGE::mixins = {};


sub new {
    my $class = shift;
    my $params = shift;
    my $self  = {};
    bless $self, $class;
    my $flds = $FIELDS;
    my $mixs = $MIXINS;
    my %original_fields = %$flds;
    my %original_mixins = %$mixs;
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
    
    # depreciated: 
    # die "No valid parameters were found, parameters are required for validation"
    #     unless $self->{params} && ref($self->{params}) eq "HASH";
    
    # validate mixin directives
    foreach (keys %{$self->{mixins}}) {
        $self->check_mixin($_, $self->{mixins}->{$_});
    }
    # validate field directives
    foreach (keys %{$self->{fields}}) {
        unless ($_ eq 'errors') {
            $self->check_field($_, $self->{fields}->{$_});
            # check for and process mixin directives
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


sub field {
    my %spec = @_;
    if (%spec) {
        my $flds = $FIELDS;
        while (my ($key, $val) = each (%spec)) {
            $val->{errors} = [];
            $val->{validation} = sub {0}
                unless $val->{validation};
            # overwrite bad, append good
            #$flds->{$key} = $val;
            if (ref($val) eq "HASH") {
                while (my ($k, $v) = each (%{$val})) {
                    $flds->{$key}->{$k} = $v;
                }
            }
        }
    }
    return 'field', %spec;
}


sub mixin {
    my %spec = @_;
    if (%spec) {
        my $mixs = $MIXINS;
        while (my ($key, $val) = each (%spec)) {
            $mixs->{$key} = $val;
        }
    }
    return 'mixin', %spec;
}


sub error {
    my ($self, @params) = @_;
    if (@params == 2) {
        # set error message
        my ($field, $error_msg) = @params;
        if (ref($field) eq "HASH" && (!ref($error_msg) && $error_msg)) {
            if (defined $self->{fields}->{$field->{name}}->{error}) {
                
                # temporary, may break stuff
                $error_msg = $self->{fields}->{$field->{name}}->{error};
                
                push @{$self->{fields}->{$field->{name}}->{errors}}, $error_msg unless
                    grep { $_ eq $error_msg } @{$self->{fields}->{$field->{name}}->{errors}};
                push @{$self->{errors}}, $error_msg unless
                    grep { $_ eq $error_msg } @{$self->{errors}};
            }
            else {
                push @{$self->{fields}->{$field->{name}}->{errors}}, $error_msg
                    unless grep { $_ eq $error_msg } @{$self->{fields}->{$field->{name}}->{errors}};
                push @{$self->{errors}}, $error_msg
                    unless grep { $_ eq $error_msg } @{$self->{errors}};
            }
        }
        else {
            die "Can't set error without proper field and error message data, " .
            "field must be a hashref with name and value keys";
        }
    }
    elsif (@params == 1) {
        # return param-specific errors
        return $self->{fields}->{$params[0]}->{errors};
    }
    else {
        # return all errors
        return $self->{errors};
    }
    return 0;
}


sub errors {
    my ($self, @args) = @_;
    return $self->error(@args);
}


sub check_mixin {
    my ($self, $mixin, $spec) = @_;
    
    my $directives = {
        required    => sub {1},
        min_length  => sub {1},
        max_length  => sub {1},
        data_type   => sub {1},
        ref_type    => sub {1},
        regex       => sub {1},
        
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


sub check_field {
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


sub use_mixin {
    my ($self, $field, $mixin_s ) = @_;
    if (ref($mixin_s) eq "ARRAY") {
        foreach my $mixin (@{$mixin_s}) {
            while (my($key, $val) = each (%{$self->{mixins}->{$mixin}})) {
                $self->{fields}->{$field}->{$key} = $val
                    unless defined $self->{fields}->{$field}->{$key};
            }
        }
    }
    else {
        while (my($key, $val) = each (%{$self->{mixins}->{$mixin_s}})) {
            $self->{fields}->{$field}->{$key} = $val
                unless defined $self->{fields}->{$field}->{$key};
        }
    }
    return 1;
}


sub use_mixin_field {
    my ($self, $field, $target) = @_;
    $self->check_field($field, $self->{fields}->{$field});
    while (my($key, $val) = each (%{$self->{fields}->{$field}})) {
        $self->{fields}->{$target}->{$key} = $val
            unless defined $self->{fields}->{$target}->{$key};
        if ($key eq 'mixin') {
            $self->use_mixin($target, $key);
        }
    }
    return 1;
}


sub validate {
    my ($self, @fields) = @_;
    if ($self->{params}) {
        if (!@fields) {
            # process all params
            foreach my $field (keys %{$self->{params}}) {
                if (!defined $self->{fields}->{$field}) {
                    die "Data validation field `$field` does not exist";
                }
                my $this = $self->{fields}->{$field};
                $this->{name} = $field;
                $this->{value} = $self->{params}->{$field};
                my @passed = (
                    $self,
                    $this,
                    $self->{params}
                );
                # execute simple validation
                $self->basic_validate($field, $this);
                # custom validation
                $self->{fields}->{$field}->{validation}->(@passed);
            }
        }
        else {
            foreach my $field (@fields) {
                if (!defined $self->{fields}->{$field}) {
                    die "Data validation field `$field` does not exist";
                }
                my $this = $self->{fields}->{$field};
                $this->{name} = $field;
                $this->{value} = $self->{params}->{$field};
                my @passed = (
                    $self,
                    $this,
                    $self->{params}
                );
                # execute simple validation
                $self->basic_validate($field, $this);
                # custom validation
                $self->{fields}->{$field}->{validation}->(@passed);
            }
        }
    }
    else {
        # if no parameters are found, instead of dying, warn and continue
        unless ($self->{params} && ref($self->{params}) eq "HASH") {
            # warn
            #     "No valid parameters were found, " .
            #     "parameters are required for validation";
            foreach my $field (keys %{$self->{fields}}) {
                my $this = $self->{fields}->{$field};
                $this->{name}  = $field;
                $this->{value} = $self->{params}->{$field};
                # execute simple validation
                $self->basic_validate($field, $this);
                # custom validation shouldn't fire without params and data
                # my @passed = ($self, $this, {});
                # $self->{fields}->{$field}->{validation}->(@passed);
            }
        }
    }
    return @{$self->{errors}} ? 0 : 1; # returns true if no errors
}


sub basic_validate {
    my ($self, $field, $this) = @_;
    
    # does field have a label, if not use field name
    my $name  = $this->{label} ? $this->{label} : "parameter `$field`";
    my $value = $this->{value};
    
    # check if required
    if ($this->{required} && (! defined $value || $value eq '')) {
        my $error = defined $this->{error} ? $this->{error} : "$name is required";
        $self->error($this, $error);
        return 1; # if required and fails, stop processing immediately
    }
    
    if ($this->{required} || $value) {
    
        # check min character length
        if (defined $this->{min_length}) {
            if ($this->{min_length}) {
                if (length($value) < $this->{min_length}){
                    my $error = defined $this->{error} ? $this->{error} :
                    "$name must contain at least " .
                        $this->{min_length} .
                        (int($this->{min_length}) > 1 ?
                         " characters" : " character");
                    $self->error($this, $error);
                }
            }
        }
        
        # check max character length
        if (defined $this->{max_length}) {
            if ($this->{max_length}) {
                if (length($value) > $this->{max_length}){
                    my $error = defined $this->{error} ? $this->{error} :
                    "$name cannot be greater than " .
                        $this->{max_length} .
                        (int($this->{max_length}) > 1 ?
                         " characters" : " character");
                    $self->error($this, $error);
                }
            }
        }
        
        # check reference type
        if (defined $this->{ref_type}) {
            if ($this->{ref_type}) {
                unless (lc(ref($value)) eq lc($this->{ref_type})) {
                    my $error = defined $this->{error} ? $this->{error} :
                    "$name is not being stored as " .
                        ($this->{ref_type} =~ /^[Aa]/ ? "an " : "a ") . 
                            $this->{ref_type} . " reference";
                    $self->error($this, $error);
                }
            }
        }
        
        # check data type
        if (defined $this->{data_type}) {
            if ($this->{data_type}) {
                
            }
        }
        
        # check against regex
        if (defined $this->{regex}) {
            if ($this->{regex}) {
                unless ($value =~ $this->{regex}) {
                    my $error = defined $this->{error} ? $this->{error} :
                    "$name failed regular expression testing " .
                        "using `$value`";
                    $self->error($this, $error);
                }
            }
        }
    }
    return 1;
}


sub basic_filter {
    my ($self, $filter, $field) = @_;
    
    # convert to lowercase
    if ($filter eq "lowercase") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =
                lc $self->{params}->{$field};
        }
    }
    # convert to uppercase
    if ($filter eq "uppercase") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =
                uc $self->{params}->{$field};
        }
    }
    # convert to titlecase
    if ($filter eq "titlecase") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =
                join " ", map (ucfirst, split (/\s/, $self->{params}->{$field}));
        }
    }
    # convert to alphanumeric
    if ($filter eq "alphanumeric") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =~
                s/[^A-Za-z0-9]//g;
        }
    }
    # convert to numeric
    if ($filter eq "numeric") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =~
                s/[^0-9]//g;
        }
    }
    # convert to alpha
    if ($filter eq "alpha") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =~
                s/[^A-Za-z]//g;
        }
    }
    # convert to digit
    if ($filter eq "digit") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =~
                s/\D//g;
        }
    }
    # convert to strip
    if ($filter eq "strip") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =~
                s/\s+/ /g;
        }
    }
    # convert to trim
    if ($filter eq "trim") {
        if (defined $self->{params}->{$field}) {
            $self->{params}->{$field} =~
                s/^\s+//o;
            $self->{params}->{$field} =~
                s/\s+$//o;
        }
    }
    # use regex
    if ($filter =~ "^CODE") {
        if (defined $self->{params}->{$field}) {
            $filter->($self->{params}->{$field});
        }
    }
    
}


sub Oogly {
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

# The has method adds a 'find-in-array' virtual list method for Template-Toolkit
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

version 0.02

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

=head2 new

The new method instantiates a new Oogly::Aagly instance.

=head2 field

The field function defines the validation rules for the specified parameter it
is named after. e.g. field 'some_data' => {...}, validates against the value of 
the hash reference where the key is `some_data`.

    field 'some_param' => {
        mixin => 'default',
        validation => sub {
            my ($v, $this, $params) = @_;
            $v->error($this, "...")
                if ...
        }
    };

    Fields are comprised of specific directives, those directives are as follows:
    name: The name of the field (auto set)
    value: The value of the parameter matching the name of the field (auto set)
    mixin: The template to be used to copy directives from
    
    mixin 'template' => {
        required => 1
    };
    
    field 'a_field' => {
        mixin => 'template'
    }
    
    mixin_field: The field to be used as a mixin(template) to copy directives from
    
    field 'a_field' => {
        required => 1,
        min_length => 2,
        max_length => 10
    };
    
    field 'b_field' => {
        mixin_field => 'a_field'
    };
    
    validation: A validation routine that returns true or false
    
    field '...' => {
        validation => sub {
            my ($self, $field, $all_parameters) = @_;
            return 1
        }
    };
    
    errors: The collection of errors encountered during processing (auto set arrayref)
    label: An alias for the field name, something more human-readable
    error: A custom error message, displayed instead of the generic ones
    required : Determines whether the field is required or not, takes 1/0 true of false
    min_length: Determines the maximum length of characters allowed
    max_length: Determines the minimum length of characters allowed
    ref_type: Determines whether the field value is a valid perl reference variable
    regex: Determines whether the field value passed the regular expression test
    
    field 'c_field' => {
        label => 'a field labeled c',
        error => 'a field labeled c cannot ',
        required => 1,
        min_length => 2,
        max_length => 25,
        ref_type => 'array',
        regex => '^\d+$'
    };
    
    filter: An alias for the filters directive, see filter method for filter names
    filters: Set filters to manipulate the data before validation
    
    field 'd_field' => {
        ...,
        filters => [
            'trim',
            'strip'
        ]
    };
    
    field 'e_field' => {
        filter => 'strip'
    };
    
    field 'f_field' => {
        filters => [
            'trim',
            sub {
                $_[0] =~ s/(abc)|(123)//;
            }
        ]
    };

=head2 mixin

The mixin function defines validation rule templates to be later reused by
more specifically defined fields.

    mixin 'default' => {
        required    => 1,
        min_length  => 4,
        max_length  => 255
    };

=head2 error

The error function is used to set and/or retrieve errors encountered or set
during validation. The error function with no parameters returns the error
message arrayref which can be used to output a single concatenated error message
a with delimeter.

    $self->error() # returns an arrayref of errors
    join '<br/>', @{$self->error()}; # html-break delimeted errors
    $self->error('some_param'); # show parameter-specific error messages arrayref
    $self->error($this, "$name must conform ..."); # set error, see `field` function

=head2 errors

The errors function is a synonym for the error function.

=head2 check_mixin

The check_mixin function is used internally to validate the defined keys and
values of mixins.

=head2 check_field

The check_field function is used internally to validate the defined keys and
values of fields.

=head2 use_mixin

The use_mixin function sequentially applies defined mixin parameteres
(as templates)to the specified field.

=head2 use_mixin_field

The use_mixin_field function copies the properties (directives) of a specified
field to the target field processing copied mixins along the way.

=head2 validate

The validate function sequentially checks the passed-in field names against their
defined validation rules and returns 0 or 1 based on the existence of errors.

=head2 basic_validate

The basic_validate function processes the pre-defined contraints e.g.,
required, min_length, max_length, etc.

=head2 basic_filter

The basic_filter function processes the pre-defined filters e.g.,
trim, strip, digit, alpha, numeric, alphanumeric, uppercase, lowercase,
titlecase, or custom etc.

=head2 Oogly

The Oogly method encapsulates fields and mixins and returns an Oogly::Aagly instance
for further validation. This method exist for situations where Oogly::Aagly is use
outside of a specific validation package.

    my $i = Oogly(
            mixins => {
                    'default' => {
                            required => 1
                    }
            },
            fields => {
                    'test1' => {
                            mixin => 'default'
                    }
            },
    );
    
    # Important store the new instance
    $o = $i->new({ test1 => '...' });
    
    if ($o->validate('test1')) {
        ...
    }

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

