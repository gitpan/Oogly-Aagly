#!C:\strawberry\perl\bin\perl.exe
use Plack::Handler::FCGI;

my $app = do('C:\Git Files\alnewkirk.com\public\code.oogly-aagly\eg\dancer-app\Test/app.psgi');
my $server = Plack::Handler::FCGI->new(nproc  => 5, detach => 1);
$server->run($app);
