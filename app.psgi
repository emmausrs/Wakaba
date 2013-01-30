# vim: set ft=perl :

use strict;

use Plack::App::WrapCGI;
use Plack::App::File;

use Plack::Builder;

# Load Wakaba
my $wakaba_app = Plack::App::WrapCGI->new(script => "./wakaba.pl")->to_app;

# Load the CAPTCHA
# FIXME: Loading this using CGI::Emulate::PSGI fucks shit up. We have to run it
# CGI style. No idea why this happens.
my $captcha_app = Plack::App::WrapCGI->new(
	script => "./captcha.pl",
	execute => 1
)->to_app;

# FIXME: Serve only certain file types, or figure out a nice and non-annoying
# way of separating board files from public web stuff. This should definitely
# not be used in production.
my $fileserv_app = Plack::App::File->new(root => "./");

my $app = builder {
	mount "/captcha.pl" => $captcha_app;
	mount "/wakaba.pl" => $wakaba_app;
	mount "/" => $fileserv_app;
};
