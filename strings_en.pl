use constant S_HOME => 'Home';										# Forwards to home page
use constant S_ADMIN => 'Manage';									# Forwards to Management Panel
use constant S_RETURN => 'Return';									# Returns to image board
use constant S_POSTING => 'Posting mode: Reply';					# Prints message in red bar atop the reply screen

use constant S_PAGETITLE => 'Page No.%d';								# Title to use on board pages.
use constant S_THREADTITLE => 'Thread No.%d';							# Page title to use if no subject is defined.

use constant S_NAME => 'Name';										# Describes name field
use constant S_EMAIL => 'Link';									# Describes e-mail field
use constant S_SUBJECT => 'Subject';								# Describes subject field
use constant S_SUBMIT => 'Submit';									# Describes submit button
use constant S_COMMENT => 'Comment';								# Describes comment field
use constant S_UPLOADFILE => 'File';								# Describes file field
use constant S_NOFILE => 'No File';									# Describes file/no file checkbox
use constant S_CAPTCHA => 'Verification';							# Describes captcha field
use constant S_PARENT => 'Parent';									# Describes parent field on admin post page
use constant S_DELPASS => 'Password';								# Describes password field
use constant S_DELEXPL => '(for post and file deletion)';			# Prints explanation for password box (to the right)
use constant S_SPAMTRAP => 'Leave these fields empty (spam trap): ';

use constant S_THUMB => 'Thumbnail displayed, click image for full size.';	# Prints instructions for viewing real source
use constant S_HIDDEN => 'Thumbnail hidden, click filename for the full image.';	# Prints instructions for viewing hidden image reply
use constant S_NOTHUMB => 'No<br />thumbnail';								# Printed when there's no thumbnail
use constant S_PICNAME => 'File: ';											# Prints text before upload name/link
use constant S_REPLY => 'Reply';											# Prints text for reply link
use constant S_OLD => 'Marked for deletion (old).';							# Prints text to be displayed before post is marked for deletion, see: retention
use constant S_ABBR => '%d posts omitted. Click Reply to view.';			# Prints text to be shown when replies are hidden
use constant S_ABBRIMG => '%d posts and %d images omitted. Click Reply to view.';						# Prints text to be shown when replies and images are hidden
use constant S_ABBRTEXT => 'Comment too long. Click <a href="%s">here</a> to view the full text.';

use constant S_REPDEL => 'Delete Post ';							# Prints text next to S_DELPICONLY (left)
use constant S_DELPICONLY => 'File Only';							# Prints text next to checkbox for file deletion (right)
use constant S_DELKEY => 'Password ';								# Prints text next to password field for deletion (left)
use constant S_DELETE => 'Delete';									# Defines deletion button's name
use constant S_REPORT => 'Report';									# Defines report button's name
use constant S_REPORTSUCCESS => 'Thank you for reporting! The staff has been notified and will fix this mess shortly.';

use constant S_PREV => 'Previous';									# Defines previous button
use constant S_FIRSTPG => 'Previous';								# Defines previous button
use constant S_NEXT => 'Next';										# Defines next button
use constant S_LASTPG => 'Next';									# Defines next button

use constant S_WEEKDAYS => ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');	# Defines abbreviated weekday names.

use constant S_BACKLOGHEAD => 'Thread Index';
use constant S_BACKLOGNUM => 'Num';
use constant S_BACKLOGSUBJECT => 'Title';
use constant S_BACKLOGPOSTS => 'Posts';
use constant S_BACKLOGLASTPOST => 'Last&nbsp;post';
use constant S_BACKLOGNOTHING => '(Nothing to show.)';

use constant S_REPORTHEAD => 'Post reporting';
use constant S_REPORTEXPL => 'You are reporting the following posts:';
use constant S_REPORTREASON => 'Please enter a report reason:';

use constant S_MANARET => 'Return';										# Returns to HTML file instead of PHP--thus no log/SQLDB update occurs
use constant S_MANAMODE => 'Manager Mode';								# Prints heading on top of Manager page

use constant S_MANALOGIN => 'User Login';							# Defines Management Panel radio button--allows the user to view the management panel (overview of all posts)
use constant S_ADMINUSER => 'Username:';
use constant S_ADMINPASS => 'Password:';							# Prints login prompt

use constant S_MANAPANEL => 'Management Panel';							# Defines Management Panel radio button--allows the user to view the management panel (overview of all posts)
use constant S_MANABANS => 'Bans/Whitelist';							# Defines Bans Panel button
use constant S_MANAPROXY => 'Proxy Panel';
use constant S_MANASPAM => 'Spam';										# Defines Spam Panel button
use constant S_MANASQLDUMP => 'SQL Dump';								# Defines SQL dump button
use constant S_MANASQLINT => 'SQL Interface';							# Defines SQL interface button
use constant S_MANAPOST => 'Manager Post';								# Defines Manager Post radio button--allows the user to post using HTML code in the comment box
use constant S_MANAREPORTS => 'Post Reports';
use constant S_MANAUSERS => 'User Accounts';
use constant S_MANAREBUILD => 'Rebuild caches';							# 
use constant S_MANARESTART => 'Restart script';										# Defines label for FastCGI restart option
use constant S_MANACLEANUP => 'Clean up';
use constant S_MANANUKE => 'Nuke board';								# 
use constant S_MANALOGOUT => 'Log out';									# 
use constant S_MANASAVE => 'Remember me on this computer';				# Defines Label for the login cookie checbox
use constant S_MANASUB => 'Go';											# Defines name for submit button in Manager Mode

use constant S_NOTAGS => 'HTML tags allowed. No formatting will be done, you must use HTML for line breaks and paragraphs.'; # Prints message on Management Board

use constant S_REPORTSNUM => 'Post No.';
use constant S_REPORTSBOARD => 'Board';
use constant S_REPORTSDATE => 'Date &amp; Time';
use constant S_REPORTSCOMMENT => 'Comment';
use constant S_REPORTSIP => 'IP';
use constant S_REPORTSDISMISS => 'Dismiss';

use constant S_USERSNAME => 'Username';
use constant S_USERSPASS => 'Password';
use constant S_USERSPASS2 => '(Confirm)';
use constant S_USERSLASTLOGIN => 'Last Login';
use constant S_USERSEMAIL => 'Email Address';
use constant S_USERSLEVEL => 'Level';
use constant S_USERSACTION => 'Action';
use constant S_USERSEDIT => 'Edit';
use constant S_USERSDELETE => 'Delete';
use constant S_USERSNEVER => '(Never)';
use constant S_USERSNONE => '(None)';
use constant S_USERSADD => 'Add User';

use constant S_MPDELETEIP => 'Delete all';
use constant S_MPDELETE => 'Delete';									# Defines for deletion button in Management Panel
use constant S_MPARCHIVE => 'Archive';
use constant S_MPRESET => 'Reset';										# Defines name for field reset button in Management Panel
use constant S_MPONLYPIC => 'File Only';								# Sets whether or not to delete only file, or entire post/thread
use constant S_MPDELETEALL => 'Del&nbsp;all';							# 
use constant S_MPBAN => 'Ban';											# Sets whether or not to delete only file, or entire post/thread
use constant S_MPTABLE => '<th>Post No.</th><th>Time</th><th>Subject</th>'.
                          '<th>Name</th><th>Comment</th><th>IP</th>';	# Explains names for Management Panel
use constant S_IMGSPACEUSAGE => '[ Space used: %s ]';				# Prints space used KB by the board under Management Panel

use constant S_BANTABLE => '<th>Type</th><th>Date</th><th>Expires</th><th colspan="2">Value</th><th>Comment</th><th>Action</th>'; # Explains names for Ban Panel
use constant S_BANIPLABEL => 'IP';
use constant S_BANMASKLABEL => 'Mask';
use constant S_BANCOMMENTLABEL => 'Comment';
use constant S_BANEXPIRESLABEL => 'Expires';
use constant S_BANWORDLABEL => 'Word';
use constant S_BANIP => 'Ban IP';
use constant S_BANWORD => 'Ban word';
use constant S_BANWHITELIST => 'Whitelist';
use constant S_BANREMOVE => 'Remove';
use constant S_BANCOMMENT => 'Comment';
use constant S_BANTRUST => 'No captcha';
use constant S_BANTRUSTTRIP => 'Tripcode';
use constant S_BANSECONDS => '(seconds)';
use constant S_BANEXPIRESNEVER => 'Never';

use constant S_PROXYTABLE => '<th>Type</th><th>IP</th><th>Expires</th><th>Date</th>'; # Explains names for Proxy Panel
use constant S_PROXYIPLABEL => 'IP';
use constant S_PROXYTIMELABEL => 'Seconds to live';
use constant S_PROXYREMOVEBLACK => 'Remove';
use constant S_PROXYWHITELIST => 'Whitelist';
use constant S_PROXYDISABLED => 'Proxy detection is currently disabled in configuration.';
use constant S_BADIP => 'Bad IP value';

use constant S_SPAMEXPL => 'This is the list of domain names Wakaba considers to be spam. One entry per line.<br />'.
                           'Blacklisting a site: <code>example.com</code><br />'.
						   'Using comments: <code>example.com # spammer</code><br />'.
						   'Using <a href="http://perldoc.perl.org/perlre.html">regular expressions</a>: <code>/example\.com/i</code>';
use constant S_SPAMREADONLY => 'This file is fetched from a remote source and cannot be edited.';
use constant S_SPAMSUBMIT => 'Save';
use constant S_SPAMCLEAR => 'Clear';
use constant S_SPAMRESET => 'Restore';

use constant S_SQLDUMP => 'Dump';

use constant S_SQLNUKE => 'Nuke password:';
use constant S_SQLEXECUTE => 'Execute';

use constant S_TOOBIG => 'This image is too large!  Upload something smaller!';
use constant S_TOOBIGORNONE => 'Either this image is too big or there is no image at all.  Yeah.';
use constant S_REPORTERR => 'Error: Cannot find reply.';					# Returns error when a reply (res) cannot be found
use constant S_UPFAIL => 'Error: Upload failed.';							# Returns error for failed upload (reason: unknown?)
use constant S_NOREC => 'Error: Cannot find record.';						# Returns error when record cannot be found
use constant S_NOCAPTCHA => 'Error: No verification code on record - it probably timed out.';	# Returns error when there's no captcha in the database for this IP/key
use constant S_BADCAPTCHA => 'Error: Wrong verification code entered.';		# Returns error when the captcha is wrong
use constant S_BADFORMAT => 'Error: File format not supported.';			# Returns error when the file is not in a supported format.
use constant S_STRREF => 'Error: String refused.';							# Returns error when a string is refused
use constant S_UNJUST => 'Error: Unjust POST.';								# Returns error on an unjust POST - prevents floodbots or ways not using POST method?
use constant S_NOPIC => 'Error: No file selected. Did you forget to click "Reply"?';	# Returns error for no file selected and override unchecked
use constant S_NOTEXT => 'Error: No comment entered.';						# Returns error for no text entered in to subject/comment
use constant S_TOOLONG => 'Error: Too many characters in text field.';		# Returns error for too many characters in a given field
use constant S_NOTALLOWED => 'Error: Posting not allowed.';					# Returns error for non-allowed post types
use constant S_SUBJECTREQUIRED => 'Error: You must enter a subject.';
use constant S_UNUSUAL => 'Error: Abnormal reply.';							# Returns error for abnormal reply? (this is a mystery!)
use constant S_BADHOST => 'Error: Host is banned.';							# Returns error for banned host ($badip string)
use constant S_BADHOSTPROXY => 'Error: Proxy is banned for being open.';	# Returns error for banned proxy ($badip string)
use constant S_RENZOKU => 'Error: Flood detected, post discarded.';			# Returns error for $sec/post spam filter
use constant S_RENZOKU2 => 'Error: Flood detected, file discarded.';		# Returns error for $sec/upload spam filter
use constant S_RENZOKU3 => 'Error: Flood detected.';						# Returns error for $sec/similar posts spam filter.
use constant S_PROXY => 'Error: Open proxy detected.';						# Returns error for proxy detection.
use constant S_DUPE => 'Error: This file has already been posted <a href="%s">here</a>.';	# Returns error when an md5 checksum already exists.
use constant S_DUPENAME => 'Error: A file with the same name already exists.';	# Returns error when an filename already exists.
use constant S_NOPOSTS => 'Error: You didn\'t select any posts!';
use constant S_REPORTSFLOOD => 'Error: You can only report up to %d posts.';
use constant S_NOTHREADERR => 'Error: Thread does not exist.';				# Returns error when a non-existant thread is accessed
use constant S_NOTEXISTPOST => 'Error: The post %d does not exist.';
use constant S_BADDELPASS => 'Error: Incorrect password for deletion.';		# Returns error for wrong password (when user tries to delete file)
use constant S_WRONGPASS => 'Error: Management password incorrect.';		# Returns error for wrong password (when trying to access Manager modes)
use constant S_NOACCESS => 'Error: You don\'t have sufficient privileges!';	# Returns error for insufficient privileges
use constant S_VIRUS => 'Error: Possible virus-infected file.';				# Returns error for malformed files suspected of being virus-infected.
use constant S_NOTWRITE => 'Error: Could not write to directory.';				# Returns error when the script cannot write to the directory, the chmod (777) is wrong
use constant S_SPAM => 'Spammers are not welcome here.';					# Returns error when detecting spam
use constant S_NOIPV6 => 'Error: IPv6 is not supported.';
use constant S_BADREFERRER => 'Error: Bad referrer.';						# Returns error for bad referrers.
use constant S_NOOEKAKI => 'Error: You cannot use oekaki on this board.';	# Returns error when oekaki is disabled and someone is trying to perform an oekaki task.
use constant S_CANNOTREPORT => 'Error: You cannot report posts on this board.';
use constant S_UNKNOWNUSER => 'Error: Unknown user ID.';
use constant S_BADPASSWORD => 'Error: Bad password.';
use constant S_PASSNOTMATCH => 'Error: The passwords don\'t match.';
use constant S_PASSTOOSHORT => 'Error: The password was too short.';
use constant S_BADUSERNAME => 'Error: Bad username.';
use constant S_BADEMAIL => 'Error: Bad email address.';
use constant S_BADLEVEL => 'Error: Access levels must be between 0 and 9999.';
use constant S_MODIFYSELF => 'Error: You cannot modify your own user level!';
use constant S_DELETESELF => 'Error: You cannot delete yourself!';
use constant S_USEREXISTS => 'Error: A user with that name or email address already exists..';
use constant S_LEVELTOOHIGH => 'Error: You cannot add users with privileges higher than yourself!';

use constant S_SQLCONF => 'SQL connection failure';							# Database connection failure
use constant S_SQLFAIL => 'Critical SQL problem!';							# SQL Failure
use constant S_BADTABLE => 'Bad database table.';
use constant S_BADTASK => 'Error: Invalid task.';

use constant S_REDIR => 'If the redirect didn\'t work, please choose one of the following mirrors:';    # Redir message for html in REDIR_DIR

use constant S_OEKPAINT => 'Painter: ';										# Describes the oekaki painter to use
use constant S_OEKSOURCE => 'Source: ';										# Describes the source selector
use constant S_OEKNEW => 'New image';										# Describes the new image option
use constant S_OEKMODIFY => 'Modify No.%d';									# Describes an option to modify an image
use constant S_OEKX => 'Width: ';											# Describes x dimension for oekaki
use constant S_OEKY => 'Height: ';											# Describes y dimension for oekaki
use constant S_OEKSUBMIT => 'Paint!';										# Oekaki button used for submit
use constant S_OEKIMGREPLY => 'Reply';

use constant S_AUTOBANCOMMENT => 'Auto-banned: %s';
use constant S_AUTOBANTRAP => 'Triggered a spam trap.';

use constant S_OEKIMGREPLY => 'Reply';
use constant S_OEKREPEXPL => 'Picture will be posted as a reply to thread <a href="%s">%s</a>.';

use constant S_OEKTOOBIG => 'The requested dimensions are too large.';
use constant S_OEKTOOSMALL => 'The requested dimensions are too small.';
use constant S_OEKUNKNOWN => 'Unknown oekaki painter requested.';
use constant S_HAXORING => 'Stop hax0ring the Gibson!';

use constant S_OEKPAINTERS => [
	{ painter=>"shi_norm", name=>"Shi Normal" },
	{ painter=>"shi_pro", name=>"Shi Pro" },
	{ painter=>"shi_norm_selfy", name=>"Shi Normal+Selfy" },
	{ painter=>"shi_pro_selfy", name=>"Shi Pro+Selfy" },
];

1;

