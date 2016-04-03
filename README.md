Wakaba 3.0.8 + modifications by Emma
====================================

This is the heavily modified version of Wakaba. See the feature list below.
Note that it isn't nearly as clean and polished as the standard Wakaba
distribution is; it's intended for advanced users only.

This README assumes you're already familiar with the standard Wakaba
distribution. If you aren't, you can get it here:
http://wakaba.c3.cx/s/web/wakaba_kareha. **Please do not ask for support on
the Wakaba support board, as they are not responsible for the stuff I
create.**

**Note**: This project is pretty much dead. I'll probably make a good
alternative some day, but for now, your best option will probably be to use
one of the many Tinyboard forks out there.

What this includes
------------------

* **General stuff**
    * Transparent and animated thumbnails.
    * Pretty file sizes instead of using bytes.
    * Optional sage checkbox instead of email field. (enabled by default)
    * Retains original file names.
    * Built-in banner rotation (similar to 4chan's).
    * Post report system.
    * The ability to force thread subjects.
    * Thread list.
    * RSS.
    * An unfinished Kareha-like template.
    * An option for turning off bumping for posts without images.
    * Cross-board citations (e.g. `>>>/b/9001`)
* **Management panel.**
    * Pagination for posts. Makes it a *lot* easier to moderate boards with
      tens of thousands of posts.
    * HTML is removed from post snippets.
    * User accounts with fine-grained permission settings.
    * Post editing for admins.
    * SQL dumps of all tables available.
	* Expiring bans.
* **Spam protection**
    * Referrer checking.
    * Advanced DNSBL support. Examples are provided in the config.
    * Remote spam definition files, i.e. you can fetch spam definitions
      from a web location.
    * Synchronisation of spam definition files (merges every file into
      one).
* **Other**
    * The ability to define "event handlers", which are basically anonymous
      subroutines that are executed when something happens (i.e. when a
	  post is made, or a post is reported).
    * Two security-related fixes.
    * Various fixes for JavaScript errors, etc.
    * FastCGI support. Unfinished and buggy, but works.
    * Partial IPv6 support (relies on
      [Net::IP](http://search.cpan.org/~manu/Net-IP/IP.pm)).
    * Much easier oekaki setup. Simply get a copy of *Shi-Painter* and
      *Palette Selfy* and dump them into the root folder.
    * Other things I forgot.

What this doesn't include
-------------------------

* Stickies.
* HTML 5 modifications from Wakaba 3.0.9 haven't been ported over. XHTML is
  better for debugging because it makes an error show up in your browser
  whenever you screwed up (if `USE_XHTML` is enabled), and there's no
  practical difference anyway.
* IPv4 CIDR was removed because it only worked on 32-bit systems. Use full
  masks (i.e. `255.255.255.0`) instead.
* IPv6 range ban/deleting doesn't work because 128-bit integers aren't
  present in MySQL. I'm not sure what to do about this.
* The *Gurochan* style was removed because it's ***ugly***.
* The various translations included with Wakaba have been removed because
  they were out-of-date.

Bugs/what is untested
---------------------

* Load balancing (it shouldn't be broken, though; I haven't touched
  anything related to it)
* Rebuilding caches prints shit in your error log because of the `ALTER
  TABLE` commands.
* SQLite support is probably broken.
* Perl <5.10 should work, but this is completely untested.

How to use
==========

Standard installation
---------------------

1. Copy all files to the web server.
2. Copy `default_config.pl` to `config.pl` and edit it.
3. Create a user account for yourself using this SQL command: `INSERT INTO
   users VALUES(null, 'yourusernamehere', 'yourpasswordhere', 0, 9999,
   'youremailaddresshere', '');`
4. Make sure `wakaba.pl`, `getpic.pl` and `captcha.pl` have the executable
   (+x) bit.
5. Hit `wakaba.pl` in your browser.

Upgrading from a standard Wakaba
--------------------------------

1. Replace all the board files with new ones.
2. Hit `wakaba.pl` in your browser to create new database tables.
3. Create a user account for yourself using this SQL command: `INSERT INTO
   users VALUES(null, 'yourusernamehere', 'yourpasswordhere', 0, 9999,
   'youremailaddresshere', '');`
4. Log in and rebuild caches.

Using PHP wrappers
------------------

Use this solution if you have Perl on the server, but no means of running
(Fast)CGI scripts on the web server. Note that you need the non-standard
*DBI* Perl module installed, or it won't work.

1. Copy everything from `extras/php_wrappers/` into the root folder.
2. Copy `default_config.pl` to `config.pl` and edit it.
3. Make sure you can't access `config.pl` from the web.
4. Change `CAPTCHA_SCRIPT` in your config to reflect the `.php` extension.
5. Hit `wakaba.php` in your browser.

You can put something like this in `.htaccess` to prevent access to Perl
files:

    <Files *.pl>
        Deny from all
    </Files>

Support and further development
===============================

There are currently no plans of further development, except to finish the
Kareha/2ch template and perhaps get range bans for IPv6 sorted out somehow.
I was planning to add multi-board support at one point, but it would be
better, IMHO, to write a new script from scratch and take multiple boards
into consideration from the beginning.

If you have any questions, shoot an email to `emma@tinychan.org`.

Licence & disclaimer
====================

This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What The Fuck You Want
To Public License, Version 2, as published by Sam Hocevar. See
http://sam.zoy.org/wtfpl/COPYING for more details.
