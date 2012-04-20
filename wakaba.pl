#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;

use CGI;
use DBI;


#
# Import settings
#

use lib '.';
BEGIN { require "config.pl"; }
BEGIN { require "config_defaults.pl"; }
BEGIN { require "strings_en.pl"; }		# edit this line to change the language
BEGIN { require "futaba_style.pl"; }	# edit this line to change the board style
BEGIN { require "captcha.pl"; }
BEGIN { require "wakautils.pl"; }



#
# Optional modules
#

my ($has_encode, $use_fastcgi, $use_parsedate);

if(CONVERT_CHARSETS)
{
	eval 'use Encode qw(decode encode)';
	$has_encode=1 unless($@);
}

if(USE_FASTCGI)
{
	eval 'use CGI::Fast';
	unless($@)
	{
		$use_fastcgi=1;

		# set up signal handlers
		# http://www.fastcgi.com/docs/faq.html#Signals
		$SIG{USR1}=\&sig_handler;
		$SIG{TERM}=\&sig_handler;
		$SIG{PIPE}='IGNORE';
	}
}

if(USE_PARSEDATE)
{
	eval 'use Time::ParseDate';
	$use_parsedate=1 unless($@);
}



#
# Global init
#

my $protocol_re=qr/(?:http|https|ftp|mailto|nntp)/;

my $ipv6_re=ipv6_regexp();

my ($query,$dbh,$task);

if($use_fastcgi)
{
	FASTCGI:
	while($query=new CGI::Fast)
	{
		init();
		last if(!$use_fastcgi);
	}
}
else { $query=new CGI; init(); }

sub init($)
{
	# This must be placed in here so we can spawn a new DB connection if the old one dies.
	if($use_fastcgi) { $dbh=DBI->connect_cached(SQL_DBI_SOURCE,SQL_USERNAME,SQL_PASSWORD,{AutoCommit=>1}) or make_error(S_SQLCONF); }
	else { $dbh=DBI->connect(SQL_DBI_SOURCE,SQL_USERNAME,SQL_PASSWORD,{AutoCommit=>1}) or make_error(S_SQLCONF); }

	$task=($query->param("task") or $query->param("action"));

	# check for admin table
	init_admin_database() if(!table_exists(SQL_ADMIN_TABLE));

	# check for proxy table
	init_proxy_database() if(!table_exists(SQL_PROXY_TABLE));

	# check for report table
	init_report_database() if(!table_exists(SQL_REPORT_TABLE));

	# check for user table
	init_user_database() if(!table_exists(SQL_USER_TABLE));

	if(!table_exists(SQL_TABLE)) # check for comments table
	{
		init_database();
		build_cache();
		make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);
	}
	elsif(!$task)
	{
		build_cache() unless -e HTML_SELF;
		make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);
	}
	elsif($task eq "post" or $task eq "oekakipost")
	{
		my ($file,$tmpname,$postfix);
		my $parent=$query->param("parent");
		my $name=$query->param("field1");
		my $email=$query->param("field2");
		my $subject=$query->param("field3");
		my $comment=$query->param("field4");
		my $password=$query->param("password");
		my $nofile=$query->param("nofile");
		my $nobump=$query->param("sage");
		my $captcha=$query->param("captcha");
		my $admin=$query->param("admin");
		my $no_captcha=$query->param("no_captcha");
		my $no_format=$query->param("no_format");

		# Oekaki
		if($task eq "oekakipost")
		{
			make_error(S_NOOEKAKI) unless(ENABLE_OEKAKI);

			my $oek_ip=$query->param("oek_ip") || $ENV{REMOTE_ADDR};
			die "Bad IP" unless($oek_ip=~/^[a-f0-9\.\:]+$/i);

			$tmpname=TMP_DIR.$oek_ip.'.png';
			open TMPFILE, $tmpname or die "Can't read uploaded file.";
			$file=\*TMPFILE;
			$postfix=OEKAKI_INFO_TEMPLATE->(decode_srcinfo($query->param("srcinfo")));
		}
		else
		{
			$file=$tmpname=$query->param("file");
		}

		post_stuff($parent,$name,$email,$subject,$comment,$file,$tmpname,$password,$nofile,$nobump,$captcha,$admin,$no_captcha,$no_format,$postfix);

		unlink $tmpname if($task eq "oekakipost");
	}
	elsif($task eq "delete" or $task eq S_DELETE)
	{
		my $password=$query->param("password");
		my $fileonly=$query->param("fileonly");
		my $archive=$query->param("archive");
		my $admin=$query->param("admin");
		my @posts=$query->param("delete");

		delete_stuff($password,$fileonly,$archive,$admin,@posts);
	}
	elsif($task eq "report" or $task eq S_REPORT)
	{
		my $sent=$query->param("sent");
		my $reason=$query->param("reason");
		my @posts=$query->param("delete");
		report_stuff($sent,$reason,@posts);
	}
	elsif($task eq "admin")
	{
		my $username=$query->param("kawaii");
		my $password=$query->param("berra"); # lol obfuscation
		my $nexttask=$query->param("nexttask");
		my $savelogin=$query->param("savelogin");
		my $usercookie=$query->cookie("wakauser");
		my $admincookie=$query->cookie("wakaadmin");

		do_login($username,$password,$nexttask,$savelogin,$usercookie,$admincookie);
	}
	elsif($task eq "logout")
	{
		do_logout();
	}
	elsif($task eq "mpanel")
	{
		my $admin=$query->param("admin");
		my $page=$query->param("page");
		make_admin_post_panel($admin,$page);
	}
	elsif($task eq "deleteall")
	{
		my $admin=$query->param("admin");
		my $ip=$query->param("ip");
		my $ipv6=$ip=~/\:/?1:$query->param("ipv6")?1:0;
		my $mask=$query->param("mask");
		delete_all($admin,parse_range($ip,$mask,$ipv6),$ipv6);
	}
	elsif($task eq "bans")
	{
		my $admin=$query->param("admin");
		make_admin_ban_panel($admin);
	}
	elsif($task eq "addip")
	{
		my $admin=$query->param("admin");
		my $type=$query->param("type");
		my $comment=$query->param("comment");
		my $ip=$query->param("ip");
		my $ipv6=$ip=~/\:/?1:$query->param("ipv6")?1:0;
		my $mask=$query->param("mask");
		my $expires=$query->param("expires");
		add_admin_entry($admin,$type,$comment,parse_range($ip,$mask,$ipv6),$ipv6,$expires);
	}
	elsif($task eq "addstring")
	{
		my $admin=$query->param("admin");
		my $type=$query->param("type");
		my $string=$query->param("string");
		my $comment=$query->param("comment");
		add_admin_entry($admin,$type,$comment,0,0,$string);
	}
	elsif($task eq "removeban")
	{
		my $admin=$query->param("admin");
		my $num=$query->param("num");
		remove_admin_entry($admin,$num);
	}
	elsif($task eq "proxy")
	{
		my $admin=$query->param("admin");
		make_admin_proxy_panel($admin);
	}
	elsif($task eq "addproxy")
	{
		my $admin=$query->param("admin");
		my $type=$query->param("type");
		my $ip=$query->param("ip");
		my $timestamp=$query->param("timestamp");
		my $date=make_date(time(),DATE_STYLE);
		add_proxy_entry($admin,$type,$ip,$timestamp,$date);
	}
	elsif($task eq "removeproxy")
	{
		my $admin=$query->param("admin");
		my $num=$query->param("num");
		remove_proxy_entry($admin,$num);
	}
	elsif($task eq "spam")
	{
		my ($admin);
		$admin=$query->param("admin");
		make_admin_spam_panel($admin);
	}
	elsif($task eq "updatespam")
	{
		my $admin=$query->param("admin");
		my $spam=$query->param("spam");
		update_spam_file($admin,$spam);
	}
	elsif($task eq "sqldump")
	{
		my $admin=$query->param("admin");
		my $table=$query->param("table");
		make_sql_dump($admin,$table);
	}
	elsif($task eq "sql")
	{
		my $admin=$query->param("admin");
		my $sql=$query->param("sql");
		make_sql_interface($admin,$sql);
	}
	elsif($task eq "mpost")
	{
		my $admin=$query->param("admin");
		make_admin_post($admin);
	}
	elsif($task eq "reports")
	{
		my $admin=$query->param("admin");
		make_report_panel($admin);
	}
	elsif($task eq "dismiss")
	{
		my $admin=$query->param("admin");
		my @num=$query->param("num");
		dismiss_reports($admin,@num);
	}
	elsif($task eq "users")
	{
		my $admin=$query->param("admin");
		make_user_panel($admin);
	}
	elsif($task eq "adduser")
	{
		my $admin=$query->param("admin");
		my $username=$query->param("username");
		my $password=$query->param("password");
		my $password2=$query->param("password2");
		my $email=$query->param("email");
		my $newlevel=$query->param("level");
		add_user($admin,$username,$password,$password2,$email,$newlevel);
	}
	elsif($task eq "edituser")
	{
		my $admin=$query->param("admin");
		my $username=$query->cookie("wakauser");
		my $num=$query->param("num");
		make_edit_user_panel($admin,$username,$num);
	}
	elsif($task eq "doedituser")
	{
		my $admin=$query->param("admin");
		my $selfuser=$query->cookie("wakauser");
		my $num=$query->param("num");
		my $email=$query->param("email");
		my $password=$query->param("password");
		my $password2=$query->param("password2");
		my $newlevel=$query->param("level");
		edit_user($admin,$selfuser,$num,$email,$password,$password2,$newlevel);
	}
	elsif($task eq "deluser")
	{
		my $admin=$query->param("admin");
		my $selfuser=$query->cookie("wakauser");
		my $num=$query->param("num");
		delete_user($admin,$selfuser,$num);
	}
	elsif($task eq "rebuild")
	{
		my $admin=$query->param("admin");
		do_rebuild_cache($admin);
	}
	elsif($task eq "restart")
	{
		my $admin=$query->param("admin");
		restart_script($admin);
	}
	elsif($task eq "cleanup")
	{
		my $admin=$query->param("admin");
		do_cleanup($admin);
	}
	elsif($task eq "nuke")
	{
		my $admin=$query->param("admin");
		do_nuke_database($admin);
	}
	elsif($task eq "paint")
	{
		make_error(S_NOOEKAKI) unless(ENABLE_OEKAKI);
		my $oek_painter=$query->param("oek_painter");
		my $oek_x=$query->param("oek_x");
		my $oek_y=$query->param("oek_y");
		my $oek_parent=$query->param("oek_parent");
		my $oek_src=$query->param("oek_src");
		make_painter($oek_painter,$oek_x,$oek_y,$oek_parent,$oek_src);
	}
	elsif($task eq "finish")
	{
		make_error(S_NOOEKAKI) unless(ENABLE_OEKAKI);
		my $oek_ip=$query->param("oek_ip") || $ENV{REMOTE_ADDR};
		my $oek_parent=$query->param("oek_parent");
		my $srcinfo=$query->param("srcinfo");
		my $tmpname=TMP_DIR.$oek_ip.'.png';

		die "Bad IP" unless($oek_ip=~/^[a-f0-9\.\:]+$/i);

		make_http_header();
		print OEKAKI_FINISH_TEMPLATE->(
			tmpname=>$tmpname,
			oek_parent=>clean_string($oek_parent),
			oek_ip=>$oek_ip,
			srcinfo=>clean_string($srcinfo),
			decodedinfo=>OEKAKI_INFO_TEMPLATE->(decode_srcinfo($srcinfo)),
		);
	}
	else { make_error(S_BADTASK); }

	unless($use_fastcgi)
	{
		$dbh->disconnect();
	}
}




#
# Cache page creation
#

sub build_cache()
{
	my ($sth,$row,@thread,@threadlist);
	my $page=0;

	# grab all posts, in thread order (ugh, ugly kludge)
	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." ORDER BY lasthit DESC,CASE parent WHEN 0 THEN num ELSE parent END ASC,num ASC") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	$row=get_decoded_hashref($sth);

	if(!$row) # no posts on the board!
	{
		build_cache_page(0,1); # make an empty page 0
	}
	else
	{
		my @threads;
		my @thread=($row);

		push @threadlist,{
			subject=>$$row{subject}||substr(strip_html($$row{comment}),0,MAX_FIELD_LENGTH)||get_filename($$row{image})||sprintf(S_THREADTITLE,$$row{num}),
			count=>1,lastactivity=>$$row{timestamp},num=>$$row{num},list=>1
		} if(MAKE_THREADLIST);

		while($row=get_decoded_hashref($sth))
		{
			if(!$$row{parent})
			{
				push @threads,{posts=>[@thread]};
				push @threadlist,{
					subject=>$$row{subject}||substr(strip_html($$row{comment}),0,MAX_FIELD_LENGTH)||get_filename($$row{image})||sprintf(S_THREADTITLE,$$row{num}),
					count=>1,lastactivity=>$$row{timestamp},num=>$$row{num},list=>@threadlist+1
				} if(MAKE_THREADLIST);
				@thread=($row); # start new thread
			}
			else
			{
				push @thread,$row;
				if(MAKE_THREADLIST)
				{
					$threadlist[-1]{lastactivity}=$$row{timestamp};
					$threadlist[-1]{count}++;
				}
			}
		}
		push @threads,{posts=>[@thread]};

		my $total=get_page_count(scalar @threads);
		my @pagethreads;
		while(@pagethreads=splice @threads,0,IMAGES_PER_PAGE)
		{
			build_cache_page($page,$total,\@threadlist,@pagethreads);
			$page++;
		}
	}

	# check for and remove old pages
	while(-e $page.PAGE_EXT)
	{
		unlink $page.PAGE_EXT;
		$page++;
	}

	if(MAKE_THREADLIST)
	{
		print_page(BACKLOG_FILE,BACKLOG_PAGE_TEMPLATE->(
			threadlist=>\@threadlist,
			title=>S_BACKLOGHEAD,
		));
	}
	elsif(-e BACKLOG_FILE) { unlink BACKLOG_FILE; }

	unlink RSS_FILE if(!ENABLE_RSS and -e RSS_FILE);
}

sub build_cache_page($$$@)
{
	my ($page,$total,$threadlist,@threads)=@_;
	my ($filename,$tmpname);

	if($page==0) { $filename=HTML_SELF; }
	else { $filename=$page.PAGE_EXT; }

	# do abbrevations and such
	foreach my $thread (@threads)
	{
		# split off the parent post, and count the replies and images
		my ($parent,@replies)=@{$$thread{posts}};
		my $replies=@replies;
		my $images=grep { $$_{image} } @replies;
		my $curr_replies=$replies;
		my $curr_images=$images;
		my $max_replies=REPLIES_PER_THREAD;
		my $max_images=(IMAGE_REPLIES_PER_THREAD or $images);

		# drop replies until we have few enough replies and images
		while($curr_replies>$max_replies or $curr_images>$max_images)
		{
			my $post=shift @replies;
			$curr_images-- if($$post{image});
			$curr_replies--;
		}

		# write the shortened list of replies back
		$$thread{posts}=[$parent,@replies];
		$$thread{omit}=$replies-$curr_replies;
		$$thread{omitimages}=$images-$curr_images;

		# abbreviate the remaining posts
		foreach my $post (@{$$thread{posts}})
		{
			my $abbreviation=abbreviate_html($$post{comment},MAX_LINES_SHOWN,APPROX_LINE_LENGTH);
			if($abbreviation)
			{
				$$post{comment}=$abbreviation;
				$$post{abbrev}=1;
			}
		}
	}

	# make rss
	# ideally this shouldn't go here, but this way we won't have to do abbreviations again, etc
	if(ENABLE_RSS and $page==0) { print_page(RSS_FILE,RSS_TEMPLATE->(threads=>\@threads)); }

	# make the list of pages
	my @pages=map +{ page=>$_ },(0..$total-1);
	foreach my $p (@pages)
	{
		if($$p{page}==0) { $$p{filename}=expand_filename(HTML_SELF) } # first page
		else { $$p{filename}=expand_filename($$p{page}.PAGE_EXT) }
		if($$p{page}==$page) { $$p{current}=1 } # current page, no link
	}

	my ($prevpage,$nextpage);
	$prevpage=$pages[$page-1]{filename} if($page!=0);
	$nextpage=$pages[$page+1]{filename} if($page!=$total-1);

	print_page($filename,PAGE_TEMPLATE->(
		oekaki=>ENABLE_OEKAKI,
		postform=>(ALLOW_TEXTONLY or ALLOW_IMAGES),
		image_inp=>ALLOW_IMAGES,
		textonly_inp=>(ALLOW_IMAGES and ALLOW_TEXTONLY),
		prevpage=>$prevpage,
		nextpage=>$nextpage,
		pages=>\@pages,
		threads=>\@threads,
		title=>$page?sprintf S_PAGETITLE,$page:'',
		threadlist=>$threadlist,
	));
}

sub build_thread_cache($)
{
	my ($thread)=@_;
	my ($sth,$row,@thread);
	my ($filename,$tmpname);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? OR parent=? ORDER BY num ASC;") or make_error(S_SQLFAIL);
	$sth->execute($thread,$thread) or make_error(S_SQLFAIL);

	while($row=get_decoded_hashref($sth)) { push(@thread,$row); }

	make_error(S_NOTHREADERR) if($thread[0]{parent});

	$filename=RES_DIR.$thread.PAGE_EXT;

	print_page($filename,PAGE_TEMPLATE->(
		oekaki=>ENABLE_OEKAKI,
		thread=>$thread,
		postform=>(ALLOW_TEXT_REPLIES or ALLOW_IMAGE_REPLIES),
		image_inp=>ALLOW_IMAGE_REPLIES,
		textonly_inp=>0,
		dummy=>$thread[$#thread]{num},
		threads=>[{posts=>\@thread}],
		title=>$thread[0]{subject} ne ''?$thread[0]{subject}:sprintf S_THREADTITLE,$thread[0]{num}
	));
}

sub print_page($$)
{
	my ($filename,$contents)=@_;

	$contents=encode_string($contents);
#		$PerlIO::encoding::fallback=0x0200 if($has_encode);
#		binmode PAGE,':encoding('.CHARSET.')' if($has_encode);

	if(USE_TEMPFILES)
	{
		my $tmpname=RES_DIR.'tmp'.int(rand(1000000000));

		open (PAGE,">$tmpname") or make_error(S_NOTWRITE);
		print PAGE $contents;
		close PAGE;

		rename $tmpname,$filename;
	}
	else
	{
		open (PAGE,">$filename") or make_error(S_NOTWRITE);
		print PAGE $contents;
		close PAGE;
	}
}

sub build_thread_cache_all()
{
	my ($sth,$row,@thread);

	$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE parent=0;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	while($row=$sth->fetchrow_arrayref())
	{
		build_thread_cache($$row[0]);
	}
}



#
# Posting
#

sub post_stuff($$$$$$$$$$$$$$$)
{
	my ($parent,$name,$email,$subject,$comment,$file,$uploadname,$password,$nofile,$nobump,$captcha,$admin,$no_captcha,$no_format,$postfix)=@_;

	# get a timestamp for future use
	my $time=time();

	# check that the request came in as a POST, or from the command line
	make_error(S_UNJUST) if($ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} ne "POST");

	run_event_handler('preprocess',SQL_TABLE,$query);

	if($admin) # check admin password - allow both encrypted and non-encrypted
	{
		check_password($admin,7000);
	}
	else
	{

		# forbid admin-only features
		make_error(S_WRONGPASS) if($no_captcha or $no_format);

		# check what kind of posting is allowed
		if($parent)
		{
			make_error(S_NOTALLOWED) if($file and !ALLOW_IMAGE_REPLIES);
			make_error(S_NOTALLOWED) if(!$file and !ALLOW_TEXT_REPLIES);
		}
		else
		{
			make_error(S_NOTALLOWED) if($file and !ALLOW_IMAGES);
			make_error(S_NOPIC) if(!$file and !ALLOW_TEXTONLY);
		}
	}

	# check for weird characters
	make_error(S_UNUSUAL) if($parent=~/[^0-9]/);
	make_error(S_UNUSUAL) if(length($parent)>10);
	make_error(S_UNUSUAL) if($name=~/[\n\r]/);
	make_error(S_UNUSUAL) if($email=~/[\n\r]/);
	make_error(S_UNUSUAL) if($subject=~/[\n\r]/);

	# check for excessive amounts of text
	make_error(S_TOOLONG) if(length($name)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($email)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($subject)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($comment)>MAX_COMMENT_LENGTH);

	# check to make sure the user selected a file, or clicked the checkbox
	make_error(S_NOPIC) if(!$parent and !$file and !$nofile and !$admin);

	# check for empty reply or empty text-only post
	make_error(S_NOTEXT) if($comment=~/^\s*$/ and !$file);

	# enforce thread subjects
	make_error(S_SUBJECTREQUIRED) if(FORCE_THREAD_SUBJECTS and !$parent and $subject=~/^\s*$/);

	# get file size, and check for limitations.
	my $size=get_file_size($file) if($file);

	# find IP
	my $ip=$ENV{REMOTE_ADDR};
	my $ipv6=$ip=~/\:/ ? 1 : 0;

	#$host = gethostbyaddr($ip);
	my $numip=dot_to_dec($ip);

	# set up cookies
	my $c_name=$name;
	my $c_email=$email;
	my $c_password=$password;

	# check if IP is whitelisted
	my $whitelisted=is_whitelisted($numip,$ipv6);

	# process the tripcode - maybe the string should be decoded later
	my $trip;
	($name,$trip)=process_tripcode($name,TRIPKEY,SECRET,CHARSET);

	# check if user is trusted
	my $trusted=is_trusted($trip);

	# check for bad referrer
	if(CHECK_REFERRER and !$admin and !$whitelisted and !$trusted)
	{
		make_error(S_BADREFERRER) if !referrer_check($ENV{'HTTP_REFERER'},$parent,STRICT_REFERRER_CHECK);
	}

	# check for bans
	ban_check($numip,$c_name,$subject,$comment,$ipv6) unless $whitelisted;

	# spam check
	my $isspam;
	$isspam = spam_engine(
		query=>$query,
		trap_fields=>SPAM_TRAP?["name","link"]:[],
		spam_files=>[SPAM_FILES],
		charset=>CHARSET,
		included_fields=>["field1","field2","field3","field4"],
		sync=>SYNC_SPAM_FILE
	) unless $whitelisted or $trusted or $admin;

	if($isspam)
	{
		# note to self: there should be some way of deciding the strictness of a spam phrase
		# for example, blocking /^https?:\/\/.+?$/s may be desirable, but it shouldn't trigger an autoban

		if(AUTOBAN_SPAMMERS)
		{
			my $com;
			if (ref($isspam) eq "HASH") { $com=S_AUTOBANTRAP; } # Spam trap
			else { $com=sprintf(S_AUTOBANCOMMENT,$isspam); } # Banned phrase, append the triggering phrase to the comment.

			my @ivals=parse_range($numip,undef,$ipv6);
			my $length=AUTOBAN_LENGTH ? $time+AUTOBAN_LENGTH : 0;

			# ban the spammer
			my $sth=$dbh->prepare("INSERT INTO ".SQL_ADMIN_TABLE." VALUES(0,?,?,?,?,?,?,?);") or make_error(S_SQLFAIL);
			$sth->execute($time,'ipban',$com,@ivals,$ipv6,$length) or make_error(S_SQLFAIL);

			# maybe add some sort of logging?
		}

		make_error(S_SPAM);
	}

	# check captcha
	check_captcha($dbh,$captcha,$ip,$parent) if(ENABLE_CAPTCHA and !$no_captcha and !$trusted);

	# proxy check
	proxy_check($ip) if (!$whitelisted and ENABLE_PROXY_CHECK);

	# check if thread exists, and get lasthit value
	my ($parent_res,$lasthit);
	if($parent)
	{
		$parent_res=get_parent_post($parent) or make_error(S_NOTHREADERR);
		$lasthit=$$parent_res{lasthit};
	}
	else
	{
		$lasthit=$time;
	}


	# kill the name if anonymous posting is being enforced
	if(FORCED_ANON)
	{
		$name='';
		$trip='';
		if($email=~/sage/i) { $email='sage'; }
		else { $email=''; }
	}

	if(!ALLOW_LINK)
	{
		if($nobump) { $email='sage'; }
		else { $email='' }
	}

	# clean up the inputs
	$email=clean_string(decode_string($email,CHARSET));
	$subject=clean_string(decode_string($subject,CHARSET));

	# fix up the email/link
	$email="mailto:$email" if $email and $email!~/^$protocol_re:/;

	# format comment
	$comment=format_comment(clean_string(decode_string($comment,CHARSET))) unless $no_format;
	$comment.=$postfix;

	# insert default values for empty fields
	$parent=0 unless $parent;
	$name=make_anonymous($ip,$time) unless $name or $trip;
	$subject=S_ANOTITLE unless $subject;
	$comment=S_ANOTEXT unless $comment;

	# flood protection - must happen after inputs have been cleaned up
	flood_check($numip,$time,$comment,$file);

	# Manager and deletion stuff - duuuuuh?

	# generate date
	my $date=make_date($time,DATE_STYLE);

	# generate ID code if enabled
	$date.=' ID:'.make_id_code($ip,$time,$email) if(DISPLAY_ID);

	# We run this here to avoid orphaned files
	run_event_handler('postprocess',SQL_TABLE,$name,$email,$subject,$comment,$file,$password,$parent);

	# copy file, do checksums, make thumbnail, etc
	my ($filename,$md5,$width,$height,$thumbnail,$tn_width,$tn_height,$origname)=process_file($file,$uploadname,$time) if($file);

	# finally, write to the database
	my $sth=$dbh->prepare("INSERT INTO ".SQL_TABLE." VALUES(null,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);") or make_error(S_SQLFAIL);
	$sth->execute($parent,$time,$lasthit,$numip,$ipv6,
	$date,$name,$trip,$email,$subject,$password,$comment,
	$filename,$origname,$size,$md5,$width,$height,$thumbnail,$tn_width,$tn_height) or make_error(S_SQLFAIL);

	if($parent) # bumping
	{
		# check for sage, or too many replies
		unless($email=~/sage/i or sage_count($parent_res)>MAX_RES)
		{
			$sth=$dbh->prepare("UPDATE ".SQL_TABLE." SET lasthit=$time WHERE num=? OR parent=?;") or make_error(S_SQLFAIL);
			$sth->execute($parent,$parent) or make_error(S_SQLFAIL);
		}
	}

	# remove old threads from the database
	trim_database();

	# update the cached HTML pages
	build_cache();

	# find out what our new thread number is
	if($filename)
	{
		$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE timestamp=? AND image=?;") or make_error(S_SQLFAIL);
		$sth->execute($time,$filename) or make_error(S_SQLFAIL);
	}
	else
	{
		$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE timestamp=? AND comment=?;") or make_error(S_SQLFAIL);
		$sth->execute($time,$comment) or make_error(S_SQLFAIL);
	}
	my $num=($sth->fetchrow_array())[0];

	# update the individual thread cache
	if($parent) { build_thread_cache($parent); }
	elsif($num) { build_thread_cache($num); }

	# set the name, email and password cookies
	make_cookies(name=>$c_name,email=>$c_email,password=>$c_password,
	-charset=>CHARSET,-autopath=>COOKIE_PATH); # yum!

	run_event_handler('finished',SQL_TABLE,$name,$email,$subject,$comment,$file,$password,$parent);

	# redirect to the appropriate page
	if($parent) { make_http_forward(RES_DIR.$parent.PAGE_EXT.($num?"#$num":""), ALTERNATE_REDIRECT); }
	elsif($num)	{ make_http_forward(RES_DIR.$num.PAGE_EXT, ALTERNATE_REDIRECT); }
	else { make_http_forward(HTML_SELF, ALTERNATE_REDIRECT); } # shouldn't happen
}

sub is_whitelisted($$)
{
	my ($numip,$ipv6)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='whitelist' AND sval1=? AND ? & ival2 = ival1 & ival2;") or make_error(S_SQLFAIL);
	$sth->execute($ipv6,$numip) or make_error(S_SQLFAIL);

	return 1 if(($sth->fetchrow_array())[0]);

	return 0;
}

sub is_trusted($)
{
	my ($trip)=@_;
	my ($sth);
        $sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='trust' AND sval1 = ?;") or make_error(S_SQLFAIL);
        $sth->execute($trip) or make_error(S_SQLFAIL);

        return 1 if(($sth->fetchrow_array())[0]);

	return 0;
}

sub clean_expired_bans()
{
	my ($sth);
	$sth=$dbh->prepare("DELETE FROM ".SQL_ADMIN_TABLE." WHERE expires AND expires<=?;") or make_error(S_SQLFAIL);
	$sth->execute(time) or make_error(S_SQLFAIL);
}

sub ban_check($$$$$)
{
	my ($numip,$name,$subject,$comment,$ipv6)=@_;
	my ($sth);

	clean_expired_bans();

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='ipban' AND sval1=? AND ? & ival2 = ival1 & ival2;") or make_error(S_SQLFAIL);
	$sth->execute($ipv6,$numip) or make_error(S_SQLFAIL);

	make_error(S_BADHOST) if(($sth->fetchrow_array())[0]);

# fucking mysql...
#	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_ADMIN_TABLE." WHERE type='wordban' AND ? LIKE '%' || sval1 || '%';") or make_error(S_SQLFAIL);
#	$sth->execute($comment) or make_error(S_SQLFAIL);
#
#	make_error(S_STRREF) if(($sth->fetchrow_array())[0]);

	$sth=$dbh->prepare("SELECT sval1 FROM ".SQL_ADMIN_TABLE." WHERE type='wordban';") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	my $row;
	while($row=$sth->fetchrow_arrayref())
	{
		my $regexp=quotemeta $$row[0];
		make_error(S_STRREF) if($comment=~/$regexp/);
		make_error(S_STRREF) if($name=~/$regexp/);
		make_error(S_STRREF) if($subject=~/$regexp/);
	}

	# etc etc etc

	return(0);
}

sub referrer_check($$$)
{
	my ($referrer,$reply,$strict)=@_;

	my $path=expand_filename(undef);
	my $html_self=HTML_SELF;
	my $page_ext=PAGE_EXT;
	my $res_dir=RES_DIR;

	if($strict)
	{
		return 1 if !$reply and $referrer=~m!^https?://(?:[^/]+@)?$ENV{SERVER_NAME}(?:\:[0-9]+)?$path(?:$html_self|[0-9]+\.$page_ext)(?:[\?#].*)?$!;
		return 1 if $reply and $referrer=~m!^https?://(?:[^/]+@)?$ENV{SERVER_NAME}(?:\:[0-9]+)?${path}${res_dir}${reply}${page_ext}(?:[\?#].*)?$!;
		return 0;
	}

	return 1 if $referrer eq ''; # Should be sufficient to prevent CSRF attacks, except in cases where browser referrers are turned off.
	return 1 if $referrer=~m!^https?://(?:[^/]+@)?$ENV{SERVER_NAME}(?:\:[0-9]+)?/!; # Allow posting from the same domain.
}

sub flood_check($$$$)
{
	my ($ip,$time,$comment,$file)=@_;
	my ($sth,$maxtime);

	if($file)
	{
		# check for to quick file posts
		$maxtime=$time-(RENZOKU2);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND timestamp>$maxtime;") or make_error(S_SQLFAIL);
		$sth->execute($ip) or make_error(S_SQLFAIL);
		make_error(S_RENZOKU2) if(($sth->fetchrow_array())[0]);
	}
	else
	{
		# check for too quick replies or text-only posts
		$maxtime=$time-(RENZOKU);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND timestamp>$maxtime;") or make_error(S_SQLFAIL);
		$sth->execute($ip) or make_error(S_SQLFAIL);
		make_error(S_RENZOKU) if(($sth->fetchrow_array())[0]);

		# check for repeated messages
		$maxtime=$time-(RENZOKU3);
		$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE ip=? AND comment=? AND timestamp>$maxtime;") or make_error(S_SQLFAIL);
		$sth->execute($ip,$comment) or make_error(S_SQLFAIL);
		make_error(S_RENZOKU3) if(($sth->fetchrow_array())[0]);
	}
}

sub proxy_check($)
{
	my ($ip)=@_;
	my ($sth);

	proxy_clean();

	# check if IP is from a known banned proxy
	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_PROXY_TABLE." WHERE type='black' AND ip = ?;") or make_error(S_SQLFAIL);
	$sth->execute($ip) or make_error(S_SQLFAIL);

	make_error(S_BADHOSTPROXY) if(($sth->fetchrow_array())[0]);

	# check if IP is from a known non-proxy
	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_PROXY_TABLE." WHERE type='white' AND ip = ?;") or make_error(S_SQLFAIL);
	$sth->execute($ip) or make_error(S_SQLFAIL);

        my $timestamp=time();
        my $date=make_date($timestamp,DATE_STYLE);

	if(($sth->fetchrow_array())[0])
	{	# known good IP, refresh entry
		$sth=$dbh->prepare("UPDATE ".SQL_PROXY_TABLE." SET timestamp=?, date=? WHERE ip=?;") or make_error(S_SQLFAIL);
		$sth->execute($timestamp,$date,$ip) or make_error(S_SQLFAIL);
	}
	else
	{	# unknown IP, check for proxy
		$sth=$dbh->prepare("INSERT INTO ".SQL_PROXY_TABLE." VALUES(null,?,?,?,?);") or make_error(S_SQLFAIL);

		if(check_dnsbl($ip,PROXY_BLACKLISTS))
		{
			$sth->execute('black',$ip,$timestamp,$date) or make_error(S_SQLFAIL);
			make_error(S_PROXY);
		}
		else
		{
			$sth->execute('white',$ip,$timestamp,$date) or make_error(S_SQLFAIL);
		}
	}
}

sub add_proxy_entry($$$$$)
{
	my ($admin,$type,$ip,$timestamp,$date)=@_;
	my ($sth);

	check_password($admin,3500);

	# Verifies IP range is sane. The price for a human-readable db...
	unless ($ip=~$ipv6_re or $ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ && $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255) {
		make_error(S_BADIP);
	}

	if ($type = 'white') { 
		$timestamp = $timestamp - PROXY_WHITE_AGE + time(); 
	}
	else
	{
		$timestamp = $timestamp - PROXY_BLACK_AGE + time(); 
	}	

	# This is to ensure user doesn't put multiple entries for the same IP
	$sth=$dbh->prepare("DELETE FROM ".SQL_PROXY_TABLE." WHERE ip=?;") or make_error(S_SQLFAIL);
	$sth->execute($ip) or make_error(S_SQLFAIL);

	# Add requested entry
	$sth=$dbh->prepare("INSERT INTO ".SQL_PROXY_TABLE." VALUES(null,?,?,?,?);") or make_error(S_SQLFAIL);
	$sth->execute($type,$ip,$timestamp,$date) or make_error(S_SQLFAIL);

        make_http_forward(get_script_name()."?admin=$admin&task=proxy",ALTERNATE_REDIRECT);
}

sub proxy_clean()
{
	my ($sth,$timestamp);

	if(PROXY_BLACK_AGE == PROXY_WHITE_AGE)
	{
		$timestamp = time() - PROXY_BLACK_AGE;
		$sth=$dbh->prepare("DELETE FROM ".SQL_PROXY_TABLE." WHERE timestamp<?;") or make_error(S_SQLFAIL);
		$sth->execute($timestamp) or make_error(S_SQLFAIL);
	} 
	else
	{
		$timestamp = time() - PROXY_BLACK_AGE;
		$sth=$dbh->prepare("DELETE FROM ".SQL_PROXY_TABLE." WHERE type='black' AND timestamp<?;") or make_error(S_SQLFAIL);
		$sth->execute($timestamp) or make_error(S_SQLFAIL);

		$timestamp = time() - PROXY_WHITE_AGE;
		$sth=$dbh->prepare("DELETE FROM ".SQL_PROXY_TABLE." WHERE type='white' AND timestamp<?;") or make_error(S_SQLFAIL);
		$sth->execute($timestamp) or make_error(S_SQLFAIL);
	}
}

sub remove_proxy_entry($$)
{
	my ($admin,$num)=@_;
	my ($sth);

	check_password($admin,3500);

	$sth=$dbh->prepare("DELETE FROM ".SQL_PROXY_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=proxy",ALTERNATE_REDIRECT);
}

sub format_comment($)
{
	my ($comment)=@_;

	# hide >>1 references from the quoting code
	$comment=~s/&gt;&gt;(?:&(gt);(\/[A-Za-z0-9-]+\/))?([0-9\-]+)/&gtgt$1;$2$3/g;

	my $handler=sub # fix up >>1 references
	{
		my $line=shift;

		# Cross-board post citation
		$line=~s!&gtgtgt;/([A-Za-z0-9-]+)/([0-9]+)!
			my $res=get_cb_post($1,$2);
			if($res) { '<a href="'.get_cb_reply_link($1,$$res{num},$$res{parent}).'">&gt;&gt;&gt;/'.$1.'/'.$2.'</a>' }
			else { "&gt;&gt;&gt;/$1/$2"; }
		!ge;

		# Post citation
		$line=~s!&gtgt;([0-9]+)!
			my $res=get_post($1);
			if($res) { '<a href="'.get_reply_link($$res{num},$$res{parent}).'" onclick="highlight('.$1.')">&gt;&gt;'.$1.'</a>' }
			else { "&gt;&gt;$1"; }
		!ge;

		return $line;
	};

	if(ENABLE_WAKABAMARK) { $comment=do_wakabamark($comment,$handler) }
	else { $comment="<p>".simple_format($comment,$handler)."</p>" }

	# fix <blockquote> styles for old stylesheets
	$comment=~s/<blockquote>/<blockquote class="unkfunc">/g;

	# restore >>1 references hidden in code blocks
	$comment=~s/&gtgt(gt)?;/'&gt;&gt;'.($1?'&gt;':'')/ge;

	return $comment;
}

sub simple_format($@)
{
	my ($comment,$handler)=@_;
	return join "<br />",map
	{
		my $line=$_;

		# make URLs into links
		$line=~s{(https?://[^\s<>"]*?)((?:\s|<|>|"|\.|\)|\]|!|\?|,|&#44;|&quot;)*(?:[\s<>"]|$))}{\<a href="$1"\>$1\</a\>$2}sgi;

		# colour quoted sections if working in old-style mode.
		$line=~s!^(&gt;.*)$!\<span class="unkfunc"\>$1\</span\>!g unless(ENABLE_WAKABAMARK);

		$line=$handler->($line) if($handler);

		$line;
	} split /\n/,$comment;
}

sub encode_string($)
{
	my ($str)=@_;

	return $str unless($has_encode);
	return encode(CHARSET,$str,0x0400);
}

sub make_anonymous($$)
{
	my ($ip,$time)=@_;

	return S_ANONAME unless(SILLY_ANONYMOUS);

	my $string=$ip;
	$string.=",".int($time/86400) if(SILLY_ANONYMOUS=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(SILLY_ANONYMOUS=~/board/i);

	srand unpack "N",hide_data($string,4,"silly",SECRET);

	return cfg_expand("%G% %W%",
		W => ["%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%","%O%%E%","%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%","%O%%E%","%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%"],
		B => ["B","B","C","D","D","F","F","G","G","H","H","M","N","P","P","S","S","W","Ch","Br","Cr","Dr","Bl","Cl","S"],
		I => ["b","d","f","h","k","l","m","n","p","s","t","w","ch","st"],
		V => ["a","e","i","o","u"],
		M => ["ving","zzle","ndle","ddle","ller","rring","tting","nning","ssle","mmer","bber","bble","nger","nner","sh","ffing","nder","pper","mmle","lly","bling","nkin","dge","ckle","ggle","mble","ckle","rry"],
		F => ["t","ck","tch","d","g","n","t","t","ck","tch","dge","re","rk","dge","re","ne","dging"],
		O => ["Small","Snod","Bard","Billing","Black","Shake","Tilling","Good","Worthing","Blythe","Green","Duck","Pitt","Grand","Brook","Blather","Bun","Buzz","Clay","Fan","Dart","Grim","Honey","Light","Murd","Nickle","Pick","Pock","Trot","Toot","Turvey"],
		E => ["shaw","man","stone","son","ham","gold","banks","foot","worth","way","hall","dock","ford","well","bury","stock","field","lock","dale","water","hood","ridge","ville","spear","forth","will"],
		G => ["Albert","Alice","Angus","Archie","Augustus","Barnaby","Basil","Beatrice","Betsy","Caroline","Cedric","Charles","Charlotte","Clara","Cornelius","Cyril","David","Doris","Ebenezer","Edward","Edwin","Eliza","Emma","Ernest","Esther","Eugene","Fanny","Frederick","George","Graham","Hamilton","Hannah","Hedda","Henry","Hugh","Ian","Isabella","Jack","James","Jarvis","Jenny","John","Lillian","Lydia","Martha","Martin","Matilda","Molly","Nathaniel","Nell","Nicholas","Nigel","Oliver","Phineas","Phoebe","Phyllis","Polly","Priscilla","Rebecca","Reuben","Samuel","Sidney","Simon","Sophie","Thomas","Walter","Wesley","William"],
	);
}

sub make_id_code($$$)
{
	my ($ip,$time,$link)=@_;

	return EMAIL_ID if($link and DISPLAY_ID=~/link/i);
	return EMAIL_ID if($link=~/sage/i and DISPLAY_ID=~/sage/i);

	return resolve_host($ENV{REMOTE_ADDR}) if(DISPLAY_ID=~/host/i);
	return $ENV{REMOTE_ADDR} if(DISPLAY_ID=~/ip/i);

	my $string="";
	$string.=",".int($time/86400) if(DISPLAY_ID=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(DISPLAY_ID=~/board/i);

	return mask_ip($ENV{REMOTE_ADDR},make_key("mask",SECRET,32).$string) if(DISPLAY_ID=~/mask/i);

	return hide_data($ip.$string,6,"id",SECRET,1);
}

sub get_post($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($thread) or make_error(S_SQLFAIL);

	return $sth->fetchrow_hashref();
}

sub get_cb_post($$)
{
	my ($board,$thread)=@_;
	my ($sth);

	return if $board=~/[^A-Za-z0-9-]/;

	$sth=$dbh->prepare("SELECT num, parent FROM $board WHERE num=?;") or return;
	$sth->execute($thread) or return;

	return $sth->fetchrow_hashref();
}

sub get_parent_post($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=? AND parent=0;") or make_error(S_SQLFAIL);
	$sth->execute($thread) or make_error(S_SQLFAIL);

	return $sth->fetchrow_hashref();
}

sub sage_count($)
{
	my ($parent)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE parent=? AND NOT ( timestamp<? AND ip=? );") or make_error(S_SQLFAIL);
	$sth->execute($$parent{num},$$parent{timestamp}+(NOSAGE_WINDOW),$$parent{ip}) or make_error(S_SQLFAIL);

	return ($sth->fetchrow_array())[0];
}

sub get_file_size($)
{
	my ($file)=@_;
	my (@filestats,$size);

	@filestats=stat $file;
	$size=$filestats[7];

	make_error(S_TOOBIG) if($size>MAX_KB*1024);
	make_error(S_TOOBIGORNONE) if($size==0); # check for small files, too?

	return($size);
}

sub process_file($$$)
{
	my ($file,$uploadname,$time)=@_;
	my %filetypes=FILETYPES;

	# make sure to read file in binary mode on platforms that care about such things
	binmode $file;

	# analyze file and check that it's in a supported format
	my ($ext,$width,$height)=analyze_image($file,$uploadname);

	my $known=($width or $filetypes{$ext});

	make_error(S_BADFORMAT) unless(ALLOW_UNKNOWN or $known);
	make_error(S_BADFORMAT) if(grep { $_ eq $ext } FORBIDDEN_EXTENSIONS);
	make_error(S_TOOBIG) if(MAX_IMAGE_WIDTH and $width>MAX_IMAGE_WIDTH);
	make_error(S_TOOBIG) if(MAX_IMAGE_HEIGHT and $height>MAX_IMAGE_HEIGHT);
	make_error(S_TOOBIG) if(MAX_IMAGE_PIXELS and $width*$height>MAX_IMAGE_PIXELS);

	# generate random filename - fudges the microseconds
	my $filebase=$time.sprintf("%03d",int(rand(1000)));
	my $filename=IMG_DIR.$filebase.'.'.$ext;
	my $thumbnail=THUMB_DIR.$filebase."s.$ext";
	$filename.=MUNGE_UNKNOWN unless($known);

	# do copying and MD5 checksum
	my ($md5,$md5ctx,$buffer);

	# prepare MD5 checksum if the Digest::MD5 module is available
	eval 'use Digest::MD5 qw(md5_hex)';
	$md5ctx=Digest::MD5->new unless($@);

	# copy file
	open (OUTFILE,">>$filename") or make_error(S_NOTWRITE);
	binmode OUTFILE;
	while (read($file,$buffer,1024)) # should the buffer be larger?
	{
		print OUTFILE $buffer;
		$md5ctx->add($buffer) if($md5ctx);
	}
	close $file;
	close OUTFILE;

	if($md5ctx) # if we have Digest::MD5, get the checksum
	{
		$md5=$md5ctx->hexdigest();
	}
	else # otherwise, try using the md5sum command
	{
		my $md5sum=`md5sum $filename`; # filename is always the timestamp name, and thus safe
		($md5)=$md5sum=~/^([0-9a-f]+)/ unless($?);
	}

	if($md5) # if we managed to generate an md5 checksum, check for duplicate files
	{
		my $sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE md5=?;") or make_error(S_SQLFAIL);
		$sth->execute($md5) or make_error(S_SQLFAIL);

		if(my $match=$sth->fetchrow_hashref())
		{
			unlink $filename; # make sure to remove the file
			make_error(sprintf(S_DUPE,get_reply_link($$match{num},$$match{parent})));
		}
	}

	# do thumbnail
	my ($tn_width,$tn_height,$tn_ext);

	if(!$width) # unsupported file
	{
		if($filetypes{$ext}) # externally defined filetype
		{
			open THUMBNAIL,$filetypes{$ext};
			binmode THUMBNAIL;
			($tn_ext,$tn_width,$tn_height)=analyze_image(\*THUMBNAIL,$filetypes{$ext});
			close THUMBNAIL;

			# was that icon file really there?
			if(!$tn_width) { $thumbnail=undef }
			else { $thumbnail=$filetypes{$ext} }
		}
		else
		{
			$thumbnail=undef;
		}
	}
	elsif($width>MAX_W or $height>MAX_H or THUMBNAIL_SMALL)
	{
		if($width<=MAX_W and $height<=MAX_H)
		{
			$tn_width=$width;
			$tn_height=$height;
		}
		else
		{
			$tn_width=MAX_W;
			$tn_height=int(($height*(MAX_W))/$width);

			if($tn_height>MAX_H)
			{
				$tn_width=int(($width*(MAX_H))/$height);
				$tn_height=MAX_H;
			}
		}

		if(STUPID_THUMBNAILING) { $thumbnail=$filename }
		else
		{
			$thumbnail=undef unless(make_thumbnail($filename,$thumbnail,$tn_width,$tn_height,THUMBNAIL_QUALITY,CONVERT_COMMAND));
		}
	}
	else
	{
		$tn_width=$width;
		$tn_height=$height;
		$thumbnail=$filename;
	}

	my $origname=$uploadname;
	$origname=~s!^.*[\\/]!!; # cut off any directory in filename
	$origname=~tr/\0//d; # fix for dangerous 0-day

	if($filetypes{$ext}) # externally defined filetype - restore the name
	{
		my $newfilename=IMG_DIR.$origname;

		unless(-e $newfilename) # verify no name clash
		{
			rename $filename,$newfilename;
			$thumbnail=$newfilename if($thumbnail eq $filename);
			$filename=$newfilename;
		}
		else
		{
			unlink $filename;
			make_error(S_DUPENAME);
		}
	}

        if(ENABLE_LOAD)
        {       # only called if files to be distributed across web     
                $ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
		my $root=$1;
                system(LOAD_SENDER_SCRIPT." $filename $root $md5 &");
        }


	return ($filename,$md5,$width,$height,$thumbnail,$tn_width,$tn_height,$origname);
}



#
# Deleting
#

sub delete_stuff($$$$@)
{
	my ($password,$fileonly,$archive,$admin,@posts)=@_;
	my ($post);

	check_password($admin,2000) if($admin);
	make_error(S_BADDELPASS) unless($password or $admin); # refuse empty password immediately

	# no password means delete always
	$password="" if($admin); 

	foreach $post (@posts)
	{
		delete_post($post,$password,$fileonly,$archive);
	}

	# update the cached HTML pages
	build_cache();

	if($admin)
	{ make_http_forward(get_script_name()."?admin=$admin&task=mpanel",ALTERNATE_REDIRECT); }
	else
	{ make_http_forward(HTML_SELF,ALTERNATE_REDIRECT); }
}

sub delete_post($$$$)
{
	my ($post,$password,$fileonly,$archiving)=@_;
	my ($sth,$row,$res,$reply);
	my $thumb=THUMB_DIR;
	my $archive=ARCHIVE_DIR;
	my $src=IMG_DIR;

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($post) or make_error(S_SQLFAIL);

	if($row=$sth->fetchrow_hashref())
	{
		make_error(S_BADDELPASS) if($password and $$row{password} ne $password);

		unless($fileonly)
		{
			# remove files from comment and possible replies
			$sth=$dbh->prepare("SELECT image,thumbnail FROM ".SQL_TABLE." WHERE num=? OR parent=?") or make_error(S_SQLFAIL);
			$sth->execute($post,$post) or make_error(S_SQLFAIL);

			while($res=$sth->fetchrow_hashref())
			{
				system(LOAD_SENDER_SCRIPT." $$res{image} &") if(ENABLE_LOAD);
	
				if($archiving)
				{
					# archive images
					rename $$res{image}, ARCHIVE_DIR.$$res{image};
					rename $$res{thumbnail}, ARCHIVE_DIR.$$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
				}
				else
				{
					# delete images if they exist
					unlink $$res{image};
					unlink $$res{thumbnail} if($$res{thumbnail}=~/^$thumb/);
				}
			}

			# remove post and possible replies
			$sth=$dbh->prepare("DELETE FROM ".SQL_TABLE." WHERE num=? OR parent=?;") or make_error(S_SQLFAIL);
			$sth->execute($post,$post) or make_error(S_SQLFAIL);
		}
		else # remove just the image and update the database
		{
			if($$row{image})
			{
				system(LOAD_SENDER_SCRIPT." $$row{image} &") if(ENABLE_LOAD);

				# remove images
				unlink $$row{image};
				unlink $$row{thumbnail} if($$row{thumbnail}=~/^$thumb/);

				$sth=$dbh->prepare("UPDATE ".SQL_TABLE." SET size=0,md5=null,thumbnail=null WHERE num=?;") or make_error(S_SQLFAIL);
				$sth->execute($post) or make_error(S_SQLFAIL);
			}
		}

		# fix up the thread cache
		if(!$$row{parent})
		{
			unless($fileonly) # removing an entire thread
			{
				if($archiving)
				{
					my $captcha = CAPTCHA_SCRIPT;
					my $line;

					open RESIN, '<', RES_DIR.$$row{num}.PAGE_EXT;
					open RESOUT, '>', ARCHIVE_DIR.RES_DIR.$$row{num}.PAGE_EXT;
					while($line = <RESIN>)
					{
						$line =~ s/img src="(.*?)$thumb/img src="$1$archive$thumb/g;
						if(ENABLE_LOAD)
						{
							my $redir = REDIR_DIR;
							$line =~ s/href="(.*?)$redir(.*?).html/href="$1$archive$src$2/g;
						}
						else
						{
							$line =~ s/href="(.*?)$src/href="$1$archive$src/g;
						}
						$line =~ s/src="[^"]*$captcha[^"]*"/src=""/g if(ENABLE_CAPTCHA);
						print RESOUT $line;	
					}
					close RESIN;
					close RESOUT;
				}
				unlink RES_DIR.$$row{num}.PAGE_EXT;
			}
			else # removing parent image
			{
				build_thread_cache($$row{num});
			}
		}
		else # removing a reply, or a reply's image
		{
			build_thread_cache($$row{parent});
		}
	}
}



#'
# Reporting
#

sub report_stuff(@)
{
	my ($sent,$reason,@posts)=@_;

	make_error(S_CANNOTREPORT) if(!ENABLE_REPORTS);

	# set up variables
	my $ip=$ENV{REMOTE_ADDR};
	my $numip=dot_to_dec($ip);
	my $ipv6=$ip=~/:/;
	my $time=time();
	my ($sth);

	# error checks
	make_error(S_NOPOSTS) if(!@posts); # no posts
	make_error(sprintf(S_REPORTSFLOOD,REPORTS_MAX)) if(@posts>REPORTS_MAX); # too many reports

	# ban check
	my $whitelisted=is_whitelisted($numip,$ipv6);
	ban_check($numip,'','','',$ipv6) unless $whitelisted;

	# we won't bother doing proxy checks - users with open proxies should be able to report too unless they're banned

	# verify each post's existence and append a hash ref with its info to the array
	my @reports=map {
		my $post=$_;
		if(my $row=get_post($post)) { $row }
		else { make_error(sprintf S_NOTEXISTPOST,$post); }
	} @posts;

	if(!$sent)
	{
		make_http_header();
		print encode_string(POST_REPORT_TEMPLATE->(posts=>\@reports));
	}
	else
	{
		make_error(S_TOOLONG) if(length($reason)>REPORTS_REASONLENGTH);

		# add reports in database
		foreach my $report (@reports)
		{
			$sth=$dbh->prepare("INSERT INTO ".SQL_REPORT_TABLE." VALUES(0,?,?,?,?,?,?);") or make_error(S_SQLFAIL);
			$sth->execute($time,$$report{num},$$report{parent},$reason,$ip,SQL_TABLE) or make_error(S_SQLFAIL);

			run_event_handler('reportsubmitted',SQL_TABLE,$$report{num},$$report{parent},$reason);
		}

		make_http_header();
		print encode_string(POST_REPORT_SUCCESSFUL->());
	}
}


#
# Admin interface
#

sub make_admin_login()
{
	make_http_header();
	print encode_string(ADMIN_LOGIN_TEMPLATE->());
}

sub make_admin_post_panel($)
{
	my ($admin,$page)=@_;
	my ($sth,$row,@posts,$size,$rowtype);
	$page=0 if(!$page);

	my $level=check_password($admin,1000);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." ORDER BY lasthit DESC,CASE parent WHEN 0 THEN num ELSE parent END ASC,num ASC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	$size=0;
	$rowtype=1;

	my $minthreads=$page*IMAGES_PER_PAGE;
	my $maxthreads=$minthreads+IMAGES_PER_PAGE;
	my $threadcount=0;

	while($row=get_decoded_hashref($sth))
	{
		if(!$$row{parent}) { $threadcount++; }

		if($threadcount>$minthreads and $threadcount<=$maxthreads)
		{
			if(!$$row{parent}) { $rowtype=1; }
			else { $rowtype^=3; }
			$$row{rowtype}=$rowtype;

			push @posts,$row;
		}

		$size+=$$row{size};
	}

	# Are we on a non-existent page?
	if($page!=0 and $page>($threadcount-1)/IMAGES_PER_PAGE)
	{
		make_http_forward(get_script_name()."?task=mpanel&admin=$admin&page=0",ALTERNATE_REDIRECT);
		return;
	}

	my @pages=map +{ page=>$_,current=>$_==$page,url=>escamp(get_script_name()."?task=mpanel&admin=$admin&page=$_") },0..($threadcount-1)/IMAGES_PER_PAGE;

	my ($prevpage,$nextpage);
	$prevpage=$page-1 if($page!=0);
	$nextpage=$page+1 if($page<$#pages);

	make_http_header();
	print encode_string(POST_PANEL_TEMPLATE->(admin=>$admin,level=>$level,posts=>\@posts,size=>$size,pages=>\@pages,next=>$nextpage,prev=>$prevpage));
}

sub make_admin_ban_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,@bans,$prevtype);

	my $level=check_password($admin,3000);

	clean_expired_bans();

	$sth=$dbh->prepare("SELECT * FROM ".SQL_ADMIN_TABLE." WHERE type='ipban' OR type='wordban' OR type='whitelist' OR type='trust' ORDER BY type ASC,num DESC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
	while($row=get_decoded_hashref($sth))
	{
		$$row{divider}=1 if($prevtype ne $$row{type});
		$prevtype=$$row{type};
		$$row{rowtype}=@bans%2+1;
		push @bans,$row;
	}

	make_http_header();
	print encode_string(BAN_PANEL_TEMPLATE->(admin=>$admin,level=>$level,bans=>\@bans,parsedate=>$use_parsedate));
}

sub make_admin_proxy_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,@scanned,$prevtype);

	my $level=check_password($admin,3400);

	proxy_clean();

	$sth=$dbh->prepare("SELECT * FROM ".SQL_PROXY_TABLE." ORDER BY timestamp ASC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
	while($row=get_decoded_hashref($sth))
	{
		$$row{divider}=1 if($prevtype ne $$row{type});
		$prevtype=$$row{type};
		$$row{rowtype}=@scanned%2+1;
		push @scanned,$row;
	}

	make_http_header();
	print encode_string(PROXY_PANEL_TEMPLATE->(admin=>$admin,level=>$level,scanned=>\@scanned));
}

sub make_admin_spam_panel($)
{
	my ($admin)=@_;
	my (@spam);
	my @spam_files=SPAM_FILES;
	my $http=$spam_files[0]=~m!^https?://!i;

	if(!$http) { @spam=read_array($spam_files[0]); }
	else { @spam=split /\r?\n|\r/, get_http($spam_files[0]); }

	my $level=check_password($admin,5000);

	make_http_header();
	print encode_string(SPAM_PANEL_TEMPLATE->(admin=>$admin,level=>$level,
	spamlines=>scalar @spam,
	readonly=>$http,
	spam=>join "\n",map { clean_string($_,1) } @spam));
}

sub make_sql_dump($)
{
	my ($admin,$table)=@_;
	my ($sth,$row,@database);

	my $level=check_password($admin,9500);

	my $tables={admin=>SQL_ADMIN_TABLE,comments=>SQL_TABLE,captcha=>SQL_CAPTCHA_TABLE,proxy=>SQL_PROXY_TABLE,report=>SQL_REPORT_TABLE};

	# make user table available for the webmaster
	if($level>=9999) { $$tables{users}=SQL_USER_TABLE; }

	if ($table)
	{
		my $tablename=$tables->{$table} or make_error(S_BADTABLE);

		$sth=$dbh->prepare("SELECT * FROM $tablename;") or make_error(S_SQLFAIL);
		$sth->execute() or make_error(S_SQLFAIL);
		while($row=get_decoded_arrayref($sth))
		{
			push @database, "INSERT INTO $tablename VALUES('".
			(join "','",map { s/\\/&#92;/g; $_ } @{$row}). # escape ' and \, and join up all values with commas and apostrophes
			"');";
		}

		print "Content-Type: application/octet-stream\n";
		print "Content-Disposition: attachment; filename=\"$table.sql\"\n\n";

		map { print "$_\n" } @database;
	}
	else
	{
		my @tables=map { +{ table=>$_ } } sort keys %$tables;

		make_http_header();
		print encode_string(SQL_DUMP_TEMPLATE->(admin=>$admin,level=>$level,tables=>\@tables));
	}
}

sub make_sql_interface($$)
{
	my ($admin,$sql)=@_;
	my ($sth,$row,@results);

	my $level=check_password($admin,9999);

	if($sql)
	{
		my @statements=grep { /^\S/ } split /\r?\n/,decode_string($sql,CHARSET,1);

		foreach my $statement (@statements)
		{
			push @results,">>> $statement";
			if($sth=$dbh->prepare($statement))
			{
				if($sth->execute())
				{
					while($row=get_decoded_arrayref($sth)) { push @results,join ' | ',@{$row} }
				}
				else { push @results,"!!! ".$sth->errstr() }
			}
			else { push @results,"!!! ".$sth->errstr() }
		}
	}

	make_http_header();
	print encode_string(SQL_INTERFACE_TEMPLATE->(admin=>$admin,level=>$level,
	results=>join "<br />",map { clean_string($_,1) } @results));
}

sub make_admin_post($)
{
	my ($admin)=@_;

	my $level=check_password($admin,7000);

	make_http_header();
	print encode_string(ADMIN_POST_TEMPLATE->(admin=>$admin,level=>$level));
}

sub make_report_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,$prevboard,@reports);

	my $level=check_password($admin,2000);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_REPORT_TABLE." ORDER BY board ASC,num DESC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
	while($row=get_decoded_hashref($sth))
	{
		$$row{divider}=1 if($prevboard ne $$row{board});
		$prevboard=$$row{board};
		$$row{rowtype}=@reports%2+1;
		push @reports, $row;
	}

	make_http_header();
	print encode_string(REPORTS_TEMPLATE->(admin=>$admin,level=>$level,reports=>\@reports));
}

sub make_user_panel($)
{
	my ($admin)=@_;
	my ($sth,$row,@users);

	my $level=check_password($admin,1);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_USER_TABLE." ORDER BY num ASC;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	while($row=get_decoded_hashref($sth))
	{
		$$row{rowtype}=@users%2+1;
		push @users,$row;
	}

	make_http_header();
	print encode_string(ADMIN_USER_PANEL_TEMPLATE->(
		admin=>$admin,
		level=>$level,
		selfuser=>$query->cookie("wakauser"),
		selflevel=>$level,
		users=>\@users
	));
}

sub make_edit_user_panel($$$)
{
	my ($admin,$username,$num)=@_;
	my ($sth,$row);

	my $level=check_password($admin,1);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_USER_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	$row=get_decoded_hashref($sth) or make_error(S_UNKNOWNUSER);

	make_error(S_NOACCESS) if($level<8500 and $$row{username} ne $username);
	make_error(S_NOACCESS) if($level<$$row{level});

	make_http_header();
	print encode_string(ADMIN_EDIT_USER_PANEL_TEMPLATE->(
		admin=>$admin,
		level=>$level,
		num=>$num,
		selfuser=>$username,
		username=>$$row{username},
		userlevel=>$$row{level},
		email=>$$row{email},
	));
}

sub do_login($$$$$)
{
	my ($username,$password,$nexttask,$savelogin,$usercookie,$admincookie)=@_;
	my $crypt;

	if($username and $password)
	{
		$crypt=crypt_password($password);
	}
	elsif($usercookie and $admincookie eq crypt_password((get_user_stuff($usercookie))[0]))
	{
		$crypt=$admincookie;
		$nexttask="mpanel";
	}

	if($crypt)
	{
		if(!$usercookie)
		{
			make_cookies(wakauser=>$username,updatelogin=>1,
			-charset=>CHARSET,-autopath=>COOKIE_PATH,-expires=>time+365*24*3600);
		}

		if($savelogin and $nexttask ne "nuke")
		{
			make_cookies(wakaadmin=>$crypt,
			-charset=>CHARSET,-autopath=>COOKIE_PATH,-expires=>time+365*24*3600);
		}

		make_http_forward(get_script_name()."?task=$nexttask&admin=$crypt",ALTERNATE_REDIRECT);
	}
	else
	{
		make_cookies(wakauser=>'',updatelogin=>'',-expires=>1) if $usercookie;
		make_admin_login();
	}
}

sub do_logout()
{
	make_cookies(wakaadmin=>"",wakauser=>"",updatelogin=>"",-expires=>1);
	make_http_forward(get_script_name()."?task=admin",ALTERNATE_REDIRECT);
}

sub do_rebuild_cache($)
{
	my ($admin)=@_;

	check_password($admin,6000);

	unlink glob RES_DIR.'*';

	repair_database();
	build_thread_cache_all();
	build_cache();

	make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);
}

sub restart_script($)
{
	my ($admin)=@_;
	check_password($admin,8400);

	make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);
	last FASTCGI;
}

sub sig_handler
{
	$use_fastcgi=0;
}

sub do_cleanup($)
{
	my ($admin)=@_;
	my ($sth,$row);

	check_password($admin,8400);

	$sth=$dbh->prepare("SELECT thumbnail FROM ".SQL_TABLE.";") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	# Get all directories 
	opendir(DIR,THUMB_DIR);
	my %files = map { $_=>1 } grep { !-d } map { THUMB_DIR.$_ } readdir(DIR); # oh god what
	closedir(DIR);

	while($row=$sth->fetchrow_hashref())
	{
		$files{$$row{thumbnail}}=0;
	}

	# Delete files
	foreach my $file (keys %files)
	{
		unlink $file if($files{$file});
	}

	make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);
}

sub add_admin_entry($$$$$$$)
{
	my ($admin,$type,$comment,$ival1,$ival2,$sval1,$expires)=@_;
	my ($sth);
	my $time=time();

	check_password($admin,4000);

	$comment=clean_string(decode_string($comment,CHARSET));

	if($use_parsedate) { $expires=parsedate($expires); } # Sexy date parsing
	else
	{
		my ($date)=grep { $$_{label} eq $expires } @{BAN_DATES()};

		if(defined $date->{time})
		{
			if($date->{time}!=0) { $expires=$time+$date->{time}; } # Use a predefined expiration time
			else { $expires=0 } # Never expire
		}
		elsif($expires!=0) { $expires=$time+$expires } # Expire in X seconds
		else { $expires=0 } # Never expire
	}

	$sth=$dbh->prepare("INSERT INTO ".SQL_ADMIN_TABLE." VALUES(null,?,?,?,?,?,?,?);") or make_error();
	$sth->execute($time,$type,$comment,$ival1,$ival2,$sval1,$expires) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=bans",ALTERNATE_REDIRECT);
}

sub remove_admin_entry($$)
{
	my ($admin,$num)=@_;
	my ($sth);

	check_password($admin,3000);

	$sth=$dbh->prepare("DELETE FROM ".SQL_ADMIN_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=bans",ALTERNATE_REDIRECT);
}

sub delete_all($$$$)
{
	my ($admin,$ip,$mask,$ipv6)=@_;
	my ($sth,$row,@posts);

	check_password($admin,2900);

	$sth=$dbh->prepare("SELECT num FROM ".SQL_TABLE." WHERE ipv6=? AND ip & ? = ? & ?;") or make_error(S_SQLFAIL);
	$sth->execute($ipv6?1:0,$mask,$ip,$mask) or make_error(S_SQLFAIL);
	while($row=$sth->fetchrow_hashref()) { push(@posts,$$row{num}); }

	delete_stuff('',0,0,$admin,@posts);
}

sub update_spam_file($$)
{
	my ($admin,$spam)=@_;

	check_password($admin,5000);

	my @spam=split /\r?\n/,$spam;
	my @spam_files=SPAM_FILES;

	make_error(S_REMOTESPAMFAIL) if($spam_files[0]=~m!^https?://!i);
	write_array($spam_files[0],@spam);

	make_http_forward(get_script_name()."?admin=$admin&task=spam",ALTERNATE_REDIRECT);
}

sub dismiss_reports($@)
{
	my ($admin,@num)=@_;
	my ($sth);

	check_password($admin,2000);

	foreach my $entry (@num)
	{
		$sth=$dbh->prepare("DELETE FROM ".SQL_REPORT_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
		$sth->execute($entry) or make_error(S_SQLFAIL);
	}

	make_http_forward(get_script_name()."?admin=$admin&task=reports",ALTERNATE_REDIRECT);
}

sub add_user($$$$$$)
{
	my ($admin,$username,$password,$password2,$email,$newlevel)=@_;
	my ($sth,$row);

	my $level=check_password($admin,9000);

	$email=~s/^\s*|\s*$//g; # strip whitespace

	make_error(S_BADUSERNAME) if($username=~/[\r\n\t]|^\s*$/);
	make_error(S_BADLEVEL) unless($newlevel=~/^\d{1,4}$/);
	make_error(S_BADPASSWORD) if($password=~/[\r\n\t]|^\s*$/);
	make_error(S_PASSNOTMATCH) if($password ne $password2);
	make_error(S_PASSTOOSHORT) if(length($password)<8);
	make_error(S_BADEMAIL) if($email and !check_email($email));
	make_error(S_LEVELTOOHIGH) if($newlevel>$level); # cannot give users a higher level than yourself

	# check for existing users
	$sth=$dbh->prepare("SELECT * FROM ".SQL_USER_TABLE." WHERE username=? OR email AND email=?;") or make_error(S_SQLFAIL);
	$sth->execute($username,$email) or make_error(S_SQLFAIL);

	make_error(S_USEREXISTS) if($sth->fetchrow_array());

	# insert into db
	$sth=$dbh->prepare("INSERT INTO ".SQL_USER_TABLE." VALUES(0,?,?,0,?,?);") or make_error(S_SQLFAIL);
	$sth->execute($username,$password,$newlevel,$email) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=users",ALTERNATE_REDIRECT);
}

sub edit_user($$$$$$$)
{
	my ($admin,$selfuser,$num,$email,$password,$password2,$newlevel)=@_;
	my ($sth,$row);

	my $level=check_password($admin,1);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_USER_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	$row=get_decoded_hashref($sth);

	make_error(S_UNKNOWNUSER) if(!$row); # no user by that id
	make_error(S_NOACCESS) if($level<8500 and $selfuser ne $$row{username}); # cannot modify other users than yourself
	make_error(S_NOACCESS) if($level<$$row{level}); # user has a higher level than you

	# password
	if($password)
	{
		make_error(S_BADPASSWORD) if($password=~/[\r\n\t]/);
		make_error(S_BADPASSWORD) if($password=~/^\s*$/);
		make_error(S_PASSNOTMATCH) if($password ne $password2);
		make_error(S_PASSTOOSHORT) if(length($password)<8);
	}
	else { $password=$$row{password}; }

	# email address
	if($email)
	{
		$email=~s/^\s*|\s*$//g; # strip whitespace
		make_error(S_BADEMAIL) unless check_email($email);
	}
	else { $email=$$row{email}; }

	# access levels
	if($newlevel ne '' and $newlevel!=$$row{level})
	{
		make_error(S_MODIFYSELF) if($selfuser eq $$row{username}); # can't change your own access level
		make_error(S_BADLEVEL) unless($newlevel=~/^\d{1,4}$/); # is the level sane?
		make_error(S_LEVELTOOHIGH) if($newlevel>$level); # cannot give users a higher level than yourself
	}
	else { $newlevel=$$row{level}; }

	$sth=$dbh->prepare("UPDATE ".SQL_USER_TABLE." SET password=?,email=?,level=? WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($password,$email,$newlevel,$num) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=users",ALTERNATE_REDIRECT);
}

sub delete_user($$$)
{
	my ($admin,$selfuser,$num)=@_;
	my ($sth,$row);

	my $level=check_password($admin,9000);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_USER_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	$row=get_decoded_hashref($sth);

	make_error(S_UNKNOWNUSER) if(!$row); # no user by that id
	make_error(S_LEVELTOOHIGH) if($$row{level}>$level); # cannot delete users with a higher level than yourself
	make_error(S_DELETESELF) if($selfuser eq $$row{username}); # cannot delete yourself

	$sth=$dbh->prepare("DELETE FROM ".SQL_USER_TABLE." WHERE num=?;") or make_error(S_SQLFAIL);
	$sth->execute($num) or make_error(S_SQLFAIL);

	make_http_forward(get_script_name()."?admin=$admin&task=users",ALTERNATE_REDIRECT);
}

sub do_nuke_database($)
{
	my ($admin)=@_;

	check_password($admin,9999);

	init_database();
	#init_admin_database();
	#init_proxy_database();

	# remove images, thumbnails and threads
	unlink glob IMG_DIR.'*';
	unlink glob THUMB_DIR.'*';
	unlink glob RES_DIR.'*';

	build_cache();

	make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);
}

sub get_user_stuff($)
{
	my $sth=$dbh->prepare("SELECT password, level FROM ".SQL_USER_TABLE." WHERE username=?;") or make_error(S_SQLFAIL);
	$sth->execute(shift) or make_error(S_SQLFAIL);

	return $sth->fetchrow_array();
}

sub check_password($$)
{
	my ($password,$minlevel)=@_;
	my ($realpass,$level,$row);
	my $username=$query->cookie("wakauser");
	my $updatelogin=$query->cookie("updatelogin");

	make_error(S_WRONGPASS) unless $username and $password; # refuse empty credentials immediately

	# get the password and access level
	($realpass,$level)=get_user_stuff($username) or make_error(S_WRONGPASS);

	make_error(S_NOACCESS) if $level<$minlevel; # insufficient privileges
	if($password eq crypt_password($realpass)) # password matches
	{
		if($updatelogin)
		{
			my $sth=$dbh->prepare("UPDATE ".SQL_USER_TABLE." SET lastlogin=? WHERE username=?;") or make_error(S_SQLFAIL);
			$sth->execute(time(),$username) or make_error(S_SQLFAIL);
			make_cookies(updatelogin=>'',-expires=>-1);
		}
		return $level;
	}

	make_error(S_WRONGPASS);
}

sub crypt_password($)
{
	my $crypt=hide_data((shift).$ENV{REMOTE_ADDR},9,"admin",SECRET,1);
	$crypt=~tr/+/./; # for web shit
	return $crypt;
}



#
# Page creation utils
#

sub make_http_header()
{
	print "Content-Type: ".get_xhtml_content_type(CHARSET,USE_XHTML)."\n";
	print "\n";
}

sub make_error($)
{
	my ($error)=@_;

	make_http_header();

	print encode_string(ERROR_TEMPLATE->(error=>$error));

	if(!$use_fastcgi and $dbh)
	{
		$dbh->{Warn}=0;
		$dbh->disconnect();
	}

	if(ERRORLOG) # could print even more data, really.
	{
		$error=~s/"/\\"/g;
		open ERRORFILE,'>>'.ERRORLOG;
		printf ERRORFILE '%s - %s - "%s" "%s"'."\n", $ENV{REMOTE_ADDR}, scalar localtime, $ENV{HTTP_USER_AGENT}, $error;
		close ERRORFILE;
	}

	# delete temp files

	stop_script();
}

sub stop_script()
{
	if($use_fastcgi) { next FASTCGI; }
	else { exit; }
}

sub get_script_name()
{
	return $ENV{SCRIPT_NAME};
}

sub get_secure_script_name()
{
	return 'https://'.$ENV{SERVER_NAME}.$ENV{SCRIPT_NAME} if(USE_SECURE_ADMIN);
	return $ENV{SCRIPT_NAME};
}

sub expand_image_filename($)
{
	my $filename=shift;

	return expand_filename(clean_path($filename)) unless ENABLE_LOAD;

	my ($self_path)=$ENV{SCRIPT_NAME}=~m!^(.*/)[^/]+$!;
	my $src=IMG_DIR;
	$filename=~/$src(.*)/;
	return $self_path.REDIR_DIR.clean_path($1).'.html';
}

sub get_reply_link($$)
{
	my ($reply,$parent)=@_;

	return expand_filename(RES_DIR.$parent.PAGE_EXT).'#'.$reply if($parent);
	return expand_filename(RES_DIR.$reply.PAGE_EXT);
}

sub get_cb_reply_link($$$)
{
	my ($board,$reply,$parent)=@_;

	return get_reply_link($reply,$parent) if($board eq SQL_TABLE);
	return expand_filename("../$board/".RES_DIR.$parent.PAGE_EXT).'#'.$reply if($parent);
	return expand_filename("../$board/".RES_DIR.$reply.PAGE_EXT);
}

sub get_page_count(;$)
{
	my $total=(shift or count_threads());
	return 0 if(!IMAGES_PER_PAGE); # avoid dividing by zero
	return int(($total+IMAGES_PER_PAGE-1)/IMAGES_PER_PAGE);
}

sub get_filetypes()
{
	my %filetypes=FILETYPES;
	$filetypes{gif}=$filetypes{jpg}=$filetypes{png}=1;
	return join ", ",map { uc } sort keys %filetypes;
}

sub parse_range($$;$)
{
	my ($ip,$mask,$ipv6)=@_;

	if($ip=~/\./ or !$ipv6)
	{
		$ip=dot_to_dec($ip) if($ip=~/^\d+\.\d+\.\d+\.\d+$/);

		if($mask=~/^\d+\.\d+\.\d+\.\d+$/) { $mask=dot_to_dec($mask); }
		else { $mask=0xffffffff; }
	}
	else
	{
		$ip=dot_to_dec($ip) if($ip=~$ipv6_re);

		if ($mask=~$ipv6_re) { $mask=dot_to_dec($mask); }
		else { $mask="340282366920938463463374607431768211455"; }; # lol
	}

	return ($ip,$mask);
}

sub run_event_handler($@)
{
	my $handler=shift;
	my %events=EVENT_HANDLERS;

	if($events{$handler})
	{
		my $error = $events{$handler}->(@_);
		if($error) { make_error($error); }
	}
}



#
# Database utils
#

sub init_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_TABLE.";") if(table_exists(SQL_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Post number, auto-increments
	"parent INTEGER,".			# Parent post for replies in threads. For original posts, must be set to 0 (and not null)
	"timestamp INTEGER,".		# Timestamp in seconds for when the post was created
	"lasthit INTEGER,".			# Last activity in thread. Must be set to the same value for BOTH the original post and all replies!
	"ip TEXT,".					# IP number of poster, in integer form!
	"ipv6 INTEGER,".			# Is this an IPv6 address? (bool)

	"date TEXT,".				# The date, as a string
	"name TEXT,".				# Name of the poster
	"trip TEXT,".				# Tripcode (encoded)
	"email TEXT,".				# Email address
	"subject TEXT,".			# Subject
	"password TEXT,".			# Deletion password (in plaintext) 
	"comment TEXT,".			# Comment text, HTML encoded.

	"image TEXT,".				# Image filename with path and extension (IE, src/1081231233721.jpg)
	"origname TEXT,".			# Original filename
	"size INTEGER,".			# File size in bytes
	"md5 TEXT,".				# md5 sum in hex
	"width INTEGER,".			# Width of image in pixels
	"height INTEGER,".			# Height of image in pixels
	"thumbnail TEXT,".			# Thumbnail filename with path and extension
	"tn_width TEXT,".			# Thumbnail width in pixels
	"tn_height TEXT".			# Thumbnail height in pixels

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub init_admin_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_ADMIN_TABLE.";") if(table_exists(SQL_ADMIN_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_ADMIN_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"date INTEGER,".				# Time when entry was added.
	"type TEXT,".				# Type of entry (ipban, wordban, etc)
	"comment TEXT,".			# Comment for the entry
	"ival1 TEXT,".			# Integer value 1 (usually IP)
	"ival2 TEXT,".			# Integer value 2 (usually netmask)
	"sval1 TEXT,".				# String value 1
	"expires INTEGER".				# Time when entry expires

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub init_proxy_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_PROXY_TABLE.";") if(table_exists(SQL_PROXY_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_PROXY_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"type TEXT,".				# Type of entry (black, white, etc)
	"ip TEXT,".				# IP address
	"timestamp INTEGER,".			# Age since epoch
	"date TEXT".				# Human-readable form of date 

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub init_report_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_REPORT_TABLE.";") if(table_exists(SQL_REPORT_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_REPORT_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"date INTEGER,".					# Timestamp of report
	"post INTEGER,".					# Reported post
	"parent INTEGER,".					# Parent of reported post
	"reason TEXT,".						# Report reason
	"ip TEXT,".							# IP address in human-readable form
	"board TEXT".						# SQL table of board the report was made on

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub init_user_database()
{
	my ($sth);

	$sth=$dbh->do("DROP TABLE ".SQL_USER_TABLE.";") if(table_exists(SQL_USER_TABLE));
	$sth=$dbh->prepare("CREATE TABLE ".SQL_USER_TABLE." (".

	"num ".get_sql_autoincrement().",".	# Entry number, auto-increments
	"username TEXT,".					# Username
	"password TEXT,".					# Password, salted and hashed.
	"lastlogin INTEGER,".				# Timestamp of last login
	"level INTEGER,".					# Privileges
	"email TEXT".

	");") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);
}

sub repair_database()
{
	my ($sth,$row,@threads,$thread);

	$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	while($row=$sth->fetchrow_hashref()) { push(@threads,$row); }

	foreach $thread (@threads)
	{
		# fix lasthit
		my ($upd);

		$upd=$dbh->prepare("UPDATE ".SQL_TABLE." SET lasthit=? WHERE parent=?;") or make_error(S_SQLFAIL);
		$upd->execute($$thread{lasthit},$$thread{num}) or make_error(S_SQLFAIL." ".$dbh->errstr());
	}

	# add missing columns

	$dbh->do("ALTER TABLE ".SQL_TABLE." ADD COLUMN ipv6 INTEGER AFTER ip;");
	$dbh->do("ALTER TABLE ".SQL_TABLE." ADD COLUMN origname TEXT AFTER image;");
	$dbh->do("ALTER TABLE ".SQL_ADMIN_TABLE." ADD COLUMN date INTEGER AFTER num;");
	$dbh->do("ALTER TABLE ".SQL_ADMIN_TABLE." ADD COLUMN expires INTEGER AFTER sval1;");
}

sub get_sql_autoincrement()
{
	return 'INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT' if(SQL_DBI_SOURCE=~/^DBI:mysql:/i);
	return 'INTEGER PRIMARY KEY' if(SQL_DBI_SOURCE=~/^DBI:SQLite:/i);
	return 'INTEGER PRIMARY KEY' if(SQL_DBI_SOURCE=~/^DBI:SQLite2:/i);

	make_error(S_SQLCONF); # maybe there should be a sane default case instead?
}

sub trim_database()
{
	my ($sth,$row,$order);

	if(TRIM_METHOD==0) { $order='num ASC'; }
	else { $order='lasthit ASC'; }

	if(MAX_AGE) # needs testing
	{
		my $mintime=time()-(MAX_AGE)*3600;

		$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0 AND timestamp<=$mintime;") or make_error(S_SQLFAIL);
		$sth->execute() or make_error(S_SQLFAIL);

		while($row=$sth->fetchrow_hashref())
		{
			delete_post($$row{num},"",0,ARCHIVE_MODE);
		}
	}

	my $threads=count_threads();
	my ($posts,$size)=count_posts();
	my $max_threads=(MAX_THREADS or $threads);
	my $max_posts=(MAX_POSTS or $posts);
	my $max_size=(MAX_MEGABYTES*1024*1024 or $size);

	while($threads>$max_threads or $posts>$max_posts or $size>$max_size)
	{
		$sth=$dbh->prepare("SELECT * FROM ".SQL_TABLE." WHERE parent=0 ORDER BY $order LIMIT 1;") or make_error(S_SQLFAIL);
		$sth->execute() or make_error(S_SQLFAIL);

		if($row=$sth->fetchrow_hashref())
		{
			my ($threadposts,$threadsize)=count_posts($$row{num});

			delete_post($$row{num},"",0,ARCHIVE_MODE);

			$threads--;
			$posts-=$threadposts;
			$size-=$threadsize;
		}
		else { last; } # shouldn't happen
	}
}

sub table_exists($)
{
	my ($table)=@_;
	my ($sth);

	return 0 unless($sth=$dbh->prepare("SELECT * FROM ".$table." LIMIT 1;"));
	return 0 unless($sth->execute());
	return 1;
}

sub count_threads()
{
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE parent=0;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	return ($sth->fetchrow_array())[0];
}

sub count_posts(;$)
{
	my ($parent)=@_;
	my ($sth,$where);

	$where="WHERE parent=$parent or num=$parent" if($parent);
	$sth=$dbh->prepare("SELECT count(*),sum(size) FROM ".SQL_TABLE." $where;") or make_error(S_SQLFAIL);
	$sth->execute() or make_error(S_SQLFAIL);

	return $sth->fetchrow_array();
}

sub thread_exists($)
{
	my ($thread)=@_;
	my ($sth);

	$sth=$dbh->prepare("SELECT count(*) FROM ".SQL_TABLE." WHERE num=? AND parent=0;") or make_error(S_SQLFAIL);
	$sth->execute($thread) or make_error(S_SQLFAIL);

	return ($sth->fetchrow_array())[0];
}

sub get_decoded_hashref($)
{
	my ($sth)=@_;

	my $row=$sth->fetchrow_hashref();

	if($row and $has_encode)
	{
		for my $k (keys %$row) # don't blame me for this shit, I got this from perlunicode.
		{ defined && /[^\000-\177]/ && Encode::_utf8_on($_) for $row->{$k}; }
	}

	return $row;
}

sub get_decoded_arrayref($)
{
	my ($sth)=@_;

	my $row=$sth->fetchrow_arrayref();

	if($row and $has_encode)
	{
		# don't blame me for this shit, I got this from perlunicode.
		defined && /[^\000-\177]/ && Encode::_utf8_on($_) for @$row;
	}

	return $row;
}



#
# Oekaki stuff
#

sub make_painter()
{
	my ($oek_painter,$oek_x,$oek_y,$oek_parent,$oek_src)=@_;
	my $ip=$ENV{'REMOTE_ADDR'};

	make_error(S_HAXORING) if($oek_x=~/[^0-9]/ or $oek_y=~/[^0-9]/ or $oek_parent=~/[^0-9]/);
	make_error(S_HAXORING) if($oek_src and !OEKAKI_ENABLE_MODIFY);
	make_error(S_HAXORING) if($oek_src=~m![^0-9a-zA-Z/\.]!);
	make_error(S_OEKTOOBIG) if($oek_x>OEKAKI_MAX_X or $oek_y>OEKAKI_MAX_Y);
	make_error(S_OEKTOOSMALL) if($oek_x<OEKAKI_MIN_X or $oek_y<OEKAKI_MIN_Y);

	my $time=time;

	if($oek_painter=~/shi/)
	{
		my $mode;
		$mode="pro" if($oek_painter=~/pro/);

		my $selfy;
		$selfy=1 if($oek_painter=~/selfy/);

		print "Content-Type: text/html; charset=Shift_JIS\n";
		print "\n";

		print OEKAKI_PAINT_TEMPLATE->(
			oek_painter=>clean_string($oek_painter),
			oek_x=>clean_string($oek_x),
			oek_y=>clean_string($oek_y),
			oek_parent=>clean_string($oek_parent),
			oek_src=>clean_string($oek_src),
			ip=>$ip,
			time=>$time,
			mode=>$mode,
			selfy=>$selfy
		);
	}
	else
	{
		make_error(S_OEKUNKNOWN);
	}
}

sub decode_srcinfo($)
{
	my ($srcinfo)=@_;
	my $oek_ip=$query->param("oek_ip") || $ENV{REMOTE_ADDR};
	my $tmpname=TMP_DIR.$oek_ip.'.png';
	my @info=split /,/,$srcinfo;
	my @stat=stat $tmpname;
	my $fileage=$stat[9];
	my ($painter)=grep { $$_{painter} eq $info[1] } @{S_OEKPAINTERS()};

	return (
		time=>clean_string(pretty_age($fileage-$info[0])),
		painter=>clean_string($$painter{name}),
		source=>clean_string($info[2]),
	);
}

sub pretty_age($)
{
	my ($age)=@_;

	return "HAXORED" if($age<0);
	return $age." s" if($age<60);
	return int($age/60)." min" if($age<3600);
	return int($age/3600)." h ".int(($age%3600)/60)." min" if($age<3600*24*7);
	return "HAXORED";
}
