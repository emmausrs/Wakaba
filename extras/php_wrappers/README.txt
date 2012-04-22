These wrappers let you run Wakaba in an environment where running CGI scripts
natively on the web server isn't an option. This often means shared hosting
environments which don't offer CGI.

To use these wrappers, copy everything in here to the root directory, then hit
wakaba.php in your web browser.

Note that the server needs Perl and the DBI module with the appropriate DB
drivers for Wakaba to work. proc_open() must also not be disabled in PHP, which
seems to be quite common on some bad hosting providers.
