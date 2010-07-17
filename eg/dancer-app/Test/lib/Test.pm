package Test;
use Dancer ':syntax';
use Test::FormFu;

our $VERSION = '0.1';

post '/process' => sub {
    my $search_param = "the search parameter contains " . params->{search} . "\n";
    template 'index', { 'test' => $search_param . form() };
};

any '/' => sub {
    template 'index', { 'test' => form() };
};

sub form {
    my $prms = params;
    my $form = Test::FormFu->new($prms);
    $form->templates('C:/repos/Oogly-Aagly/eg/dancer-app/Test/views/elements/');
    return $form->render('search', '/process', 'search');
}

true;
