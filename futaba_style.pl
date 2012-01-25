use strict;

BEGIN { require "wakautils.pl" }



use constant NORMAL_HEAD_INCLUDE => q{

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<title><if $title><var $title> - </if><const TITLE></title>
<meta http-equiv="Content-Type" content="text/html;charset=<const CHARSET>" />
<link rel="shortcut icon" href="<var expand_filename(FAVICON)>" />

<style type="text/css">
body { margin: 0; padding: 8px; margin-bottom: auto; }
blockquote blockquote { margin-left: 0em }
form { margin-bottom: 0px }
form .trap { display:none }
.postarea { text-align: center }
.postarea table { margin: 0px auto; text-align: left }
.thumb { border: none; float: left; margin: 2px 20px }
.nothumb { float: left; background: #eee; border: 2px dashed #aaa; text-align: center; margin: 2px 20px; padding: 1em 0.5em 1em 0.5em; }
.reply blockquote, blockquote :last-child { margin-bottom: 0em }
.reflink a { color: inherit; text-decoration: none }
.reply .filesize, .highlight .filesize { margin-left: 20px }
.userdelete { float: right; text-align: center; white-space: nowrap }
.replypage .replylink { display: none }
.footer { clear: both }
</style>

<loop $stylesheets>
<link rel="<if !$default>alternate </if>stylesheet" type="text/css" href="<var $path><var $filename>" title="<var $title>" />
</loop>

<script type="text/javascript">var style_cookie="<const STYLE_COOKIE>";</script>
<script type="text/javascript" src="<var expand_filename(JS_FILE)>"></script>
</head>
<if $thread><body class="replypage">
<else><body></if>

}.include("include/header.html").q{

<div class="adminbar">
<loop $stylesheets>
	[<a href="javascript:set_stylesheet('<var $title>')"><var $title></a>]
</loop>
-
[<a href="<var expand_filename(HOME)>" target="_top"><const S_HOME></a>]
[<a href="<var get_secure_script_name()>?task=admin"><const S_ADMIN></a>]
</div>

<div class="logo">
<if SHOWTITLEIMG==1><img src="<var expand_filename(TITLEIMG)>" alt="<const TITLE>" /></if>
<if SHOWTITLEIMG==2><img src="<var expand_filename(TITLEIMG)>" onclick="this.src=this.src;" alt="<const TITLE>" /></if>
<if SHOWTITLEIMG and SHOWTITLETXT><br /></if>
<if SHOWTITLETXT><const TITLE></if>
</div><hr />
};

use constant NORMAL_FOOT_INCLUDE => include("include/footer.html").q{

</body></html>
};

use constant PAGE_TEMPLATE => compile_template(NORMAL_HEAD_INCLUDE.q{

<if $thread>
	[<a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a>]
	<div class="theader"><const S_POSTING></div>
</if>

<if $oekaki>
	<if $thread><hr /></if>
	<div align="center">
	<form action="<var $self>" method="get">
	<input type="hidden" name="task" value="paint" />
	<if $thread><input type="hidden" name="oek_parent" value="<var $thread>" /></if>

	<const S_OEKPAINT>
	<select name="oek_painter">

	<loop S_OEKPAINTERS>
		<if $painter eq OEKAKI_DEFAULT_PAINTER>
			<option value="<var $painter>" selected="selected"><var $name></option>
		<else>
			<option value="<var $painter>"><var $name></option>
		</if>
	</loop>
	</select>

	<const S_OEKX><input type="text" name="oek_x" size="3" value="<const OEKAKI_DEFAULT_X>" />
	<const S_OEKY><input type="text" name="oek_y" size="3" value="<const OEKAKI_DEFAULT_Y>" />

	<if OEKAKI_ENABLE_MODIFY and $thread>
		<const S_OEKSOURCE>
		<select name="oek_src">
		<option value=""><const S_OEKNEW></option>

		<loop $threads>
			<loop $posts>
				<if $image>
					<option value="<var $image>"><var sprintf S_OEKMODIFY,$num></option>
				</if>
			</loop>
		</loop>
		</select>
	</if>

	<input type="submit" value="<const S_OEKSUBMIT>" />
	</form>
	</div><hr />
</if>

<if $postform>
	<div class="postarea">
	<form id="postform" action="<var $self>" method="post" enctype="multipart/form-data">

	<input type="hidden" name="task" value="post" />
	<if $thread><input type="hidden" name="parent" value="<var $thread>" /></if>
	<if !$image_inp and !$thread and ALLOW_TEXTONLY>
		<input type="hidden" name="nofile" value="1" />
	</if>
	<if FORCED_ANON><input type="hidden" name="name" /></if>
	<if SPAM_TRAP><div class="trap"><const S_SPAMTRAP><input type="text" name="name" size="28" autocomplete="off" /><input type="text" name="link" size="28" autocomplete="off" /></div></if>

	<table><tbody>
	<if !FORCED_ANON><tr><td class="postblock"><const S_NAME></td><td><input type="text" name="field1" size="28" /></td></tr></if>
	<tr><td class="postblock"><const S_EMAIL></td><td><input type="text" name="field2" size="28" /></td></tr>
	<tr><td class="postblock"><const S_SUBJECT></td><td><input type="text" name="field3" size="35" />
	<input type="submit" value="<const S_SUBMIT>" /></td></tr>
	<tr><td class="postblock"><const S_COMMENT></td><td><textarea name="field4" cols="48" rows="4"></textarea></td></tr>

	<if $image_inp>
		<tr><td class="postblock"><const S_UPLOADFILE></td><td><input type="file" name="file" size="35" />
		<if $textonly_inp>[<label><input type="checkbox" name="nofile" value="on" /><const S_NOFILE> ]</label></if>
		</td></tr>
	</if>

	<if ENABLE_CAPTCHA>
		<tr><td class="postblock"><const S_CAPTCHA></td><td><input type="text" name="captcha" size="10" />
		<img alt="" src="<var expand_filename(CAPTCHA_SCRIPT)>?key=<var get_captcha_key($thread)>&amp;dummy=<var $dummy>" />
		</td></tr>
	</if>

	<tr><td class="postblock"><const S_DELPASS></td><td><input type="password" name="password" size="8" /> <const S_DELEXPL></td></tr>
	<tr><td colspan="2">
	<div class="rules">}.include("include/rules.html").q{</div></td></tr>
	</tbody></table></form></div>
	<script type="text/javascript">set_inputs("postform")</script>

	<hr />
</if>

<form id="delform" action="<var $self>" method="post">

<loop $threads>
	<loop $posts>
		<if !$parent>
			<if $image>
				<span class="filesize"><const S_PICNAME><a target="_blank" href="<var expand_image_filename($image)>"><var get_filename($image)></a>
				-(<em><var $size> B, <var $width>x<var $height><if $thread and $origname>, <span title="<var clean_string($origname)>"><var show_filename($origname)></if></span></em>)</span><br />

				<if $thumbnail>
					<a target="_blank" href="<var expand_image_filename($image)>">
					<img src="<var expand_filename($thumbnail)>" width="<var $tn_width>" height="<var $tn_height>" alt="<var $size>" class="thumb" /></a>
				</if>
				<if !$thumbnail>
					<if DELETED_THUMBNAIL>
						<a target="_blank" href="<var expand_image_filename(DELETED_IMAGE)>">
						<img src="<var expand_filename(DELETED_THUMBNAIL)>" width="<var $tn_width>" height="<var $tn_height>" alt="" class="thumb" /></a>
					</if>
					<if !DELETED_THUMBNAIL>
						<div class="nothumb"><a target="_blank" href="<var expand_image_filename($image)>"><const S_NOTHUMB></a></div>
					</if>
				</if>
			</if>

			<a name="<var $num>"></a>
			<label><input type="checkbox" name="delete" value="<var $num>" />
			<span class="filetitle"><var $subject></span>
			<if $email><span class="postername"><a href="<var $email>"><var $name></a></span><if $trip><span class="postertrip"><a href="<var $email>"><var $trip></a></span></if></if>
			<if !$email><span class="postername"><var $name></span><if $trip><span class="postertrip"><var $trip></span></if></if>
			<var $date></label>
			<span class="reflink">
			<if !$thread>
				<a href="<var get_reply_link($num,0)>#<var $num>">No.</a><a href="<var get_reply_link($num,0)>#i<var $num>"><var $num></a>
			<else>
				<a href="<var get_reply_link($num,0)>#<var $num>">No.</a><a href="javascript:insert('&gt;&gt;<var $num>')"><var $num></a>
			</if>
			</span>&nbsp;
			<if !$thread>[<a href="<var get_reply_link($num,0)>"><const S_REPLY></a>]</if>

			<blockquote>
			<var $comment>
			<if $abbrev><div class="abbrev"><var sprintf(S_ABBRTEXT,get_reply_link($num,$parent))></div></if>
			</blockquote>

			<if $omit>
				<span class="omittedposts">
				<if $omitimages><var sprintf S_ABBRIMG,$omit,$omitimages></if>
				<if !$omitimages><var sprintf S_ABBR,$omit></if>
				</span>
			</if>
		</if>
		<if $parent>
			<table><tbody><tr><td class="doubledash">&gt;&gt;</td>
			<td class="reply" id="reply<var $num>">

			<a name="<var $num>"></a>
			<label><input type="checkbox" name="delete" value="<var $num>" />
			<span class="replytitle"><var $subject></span>
			<if $email><span class="commentpostername"><a href="<var $email>"><var $name></a></span><if $trip><span class="postertrip"><a href="<var $email>"><var $trip></a></span></if></if>
			<if !$email><span class="commentpostername"><var $name></span><if $trip><span class="postertrip"><var $trip></span></if></if>
			<var $date></label>
			<span class="reflink">
			<if !$thread>
				<a href="<var get_reply_link($parent,0)>#<var $num>">No.</a><a href="<var get_reply_link($parent,0)>#i<var $num>"><var $num></a>
			<else>
				<a href="<var get_reply_link($parent,0)>#<var $num>">No.</a><a href="javascript:insert('&gt;&gt;<var $num>')"><var $num></a>
			</if>
			</span>&nbsp;

			<if $image>
				<br />
				<span class="filesize"><const S_PICNAME><a target="_blank" href="<var expand_image_filename($image)>"><var get_filename($image)></a>
				-(<em><var $size> B, <var $width>x<var $height><if $thread and $origname>, <span title="<var clean_string($origname)>"><var show_filename($origname)></if></span></em>)</span><br />

				<if $thumbnail>
					<a target="_blank" href="<var expand_image_filename($image)>">
					<img src="<var expand_filename($thumbnail)>" width="<var $tn_width>" height="<var $tn_height>" alt="<var $size>" class="thumb" /></a>
				</if>
				<if !$thumbnail>
					<if DELETED_THUMBNAIL>
						<a target="_blank" href="<var expand_image_filename(DELETED_IMAGE)>">
						<img src="<var expand_filename(DELETED_THUMBNAIL)>" width="<var $tn_width>" height="<var $tn_height>" alt="" class="thumb" /></a>
					</if>
					<if !DELETED_THUMBNAIL>
						<div class="nothumb"><a target="_blank" href="<var expand_image_filename($image)>"><const S_NOTHUMB></a></div>
					</if>
				</if>
			</if>

			<blockquote>
			<var $comment>
			<if $abbrev><div class="abbrev"><var sprintf(S_ABBRTEXT,get_reply_link($num,$parent))></div></if>
			</blockquote>

			</td></tr></tbody></table>
		</if>
	</loop>
	<br clear="left" /><hr />
</loop>

<table class="userdelete"><tbody><tr><td>
<input type="hidden" name="task" value="delete" />
<const S_REPDEL>[<label><input type="checkbox" name="fileonly" value="on" /><const S_DELPICONLY></label>]<br />
<const S_DELKEY><input type="password" name="password" size="8" />
<input value="<const S_DELETE>" type="submit" /></td></tr></tbody></table>
</form>
<script type="text/javascript">set_delpass("delform")</script>

<if !$thread>
	<table border="1"><tbody><tr><td>

	<if $prevpage><form method="get" action="<var $prevpage>"><input value="<const S_PREV>" type="submit" /></form></if>
	<if !$prevpage><const S_FIRSTPG></if>

	</td><td>

	<loop $pages>
		<if !$current>[<a href="<var $filename>"><var $page></a>]</if>
		<if $current>[<var $page>]</if>
	</loop>

	</td><td>

	<if $nextpage><form method="get" action="<var $nextpage>"><input value="<const S_NEXT>" type="submit" /></form></if>
	<if !$nextpage><const S_LASTPG></if>

	</td></tr></tbody></table><br clear="all" />
<else>
	[<a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a>]
</if>

}.NORMAL_FOOT_INCLUDE);



use constant ERROR_TEMPLATE => compile_template(NORMAL_HEAD_INCLUDE.q{

<h1 style="text-align: center"><var $error><br /><br />
<a href="<var escamp($ENV{HTTP_REFERER})>"><const S_RETURN></a><br /><br />
</h1>

}.NORMAL_FOOT_INCLUDE);



#
# Admin pages
#

use constant MANAGER_HEAD_INCLUDE => NORMAL_HEAD_INCLUDE.q{

[<a href="<var expand_filename(HTML_SELF)>"><const S_MANARET></a>]
<if $admin>
	[<a href="<var $self>?task=mpanel&amp;admin=<var $admin>"><const S_MANAPANEL></a>]
	[<a href="<var $self>?task=bans&amp;admin=<var $admin>"><const S_MANABANS></a>]
	[<a href="<var $self>?task=proxy&amp;admin=<var $admin>"><const S_MANAPROXY></a>]
	[<a href="<var $self>?task=spam&amp;admin=<var $admin>"><const S_MANASPAM></a>]
	[<a href="<var $self>?task=sqldump&amp;admin=<var $admin>"><const S_MANASQLDUMP></a>]
	[<a href="<var $self>?task=sql&amp;admin=<var $admin>"><const S_MANASQLINT></a>]
	[<a href="<var $self>?task=mpost&amp;admin=<var $admin>"><const S_MANAPOST></a>]
	[<a href="<var $self>?task=rebuild&amp;admin=<var $admin>"><const S_MANAREBUILD></a>]
	[<a href="<var $self>?task=logout"><const S_MANALOGOUT></a>]
</if>
<div class="passvalid"><const S_MANAMODE></div><br />
};

use constant ADMIN_LOGIN_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div align="center"><form action="<var $self>" method="post">
<input type="hidden" name="task" value="admin" />
<const S_ADMINPASS>
<input type="password" name="berra" size="8" value="" />
<br />
<label><input type="checkbox" name="savelogin" /> <const S_MANASAVE></label>
<br />
<select name="nexttask">
<option value="mpanel"><const S_MANAPANEL></option>
<option value="bans"><const S_MANABANS></option>
<option value="proxy"><const S_MANAPROXY></option>
<option value="spam"><const S_MANASPAM></option>
<option value="sqldump"><const S_MANASQLDUMP></option>
<option value="sql"><const S_MANASQLINT></option>
<option value="mpost"><const S_MANAPOST></option>
<option value="rebuild"><const S_MANAREBUILD></option>
<option value=""></option>
<option value="restart"><const S_MANARESTART></option>
<option value="nuke"><const S_MANANUKE></option>
</select>
<input type="submit" value="<const S_MANASUB>" />
</form></div>

}.NORMAL_FOOT_INCLUDE);


use constant POST_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANAPANEL></div>

<form action="<var $self>" method="post">
<input type="hidden" name="task" value="delete" />
<input type="hidden" name="admin" value="<var $admin>" />

<div class="delbuttons">
<input type="submit" value="<const S_MPDELETE>" />
<input type="submit" name="archive" value="<const S_MPARCHIVE>" />
<input type="reset" value="<const S_MPRESET>" />
[<label><input type="checkbox" name="fileonly" value="on" /><const S_MPONLYPIC></label>]
</div>

<table align="center" style="white-space: nowrap"><tbody>
<tr class="managehead"><const S_MPTABLE></tr>

<loop $posts>
	<if !$parent><tr class="managehead"><th colspan="6"></th></tr></if>

	<tr class="row<var $rowtype>">

	<if !$image><td></if>
	<if $image><td rowspan="2"></if>
	<label><input type="checkbox" name="delete" value="<var $num>" /><big><b><var $num></b></big>&nbsp;&nbsp;</label></td>

	<td><var make_date($timestamp,"tiny")></td>
	<td><var clean_string(substr $subject,0,20)></td>
	<td><b><var clean_string(substr $name,0,30)></b><var $trip></td>
	<td><var clean_string(substr strip_html($comment),0,50)></td>
	<td><var dec_to_dot($ip,$ipv6)>
		[<a href="<var $self>?admin=<var $admin>&amp;task=deleteall&amp;ip=<var $ip>&amp;ipv6=<var $ipv6>"><const S_MPDELETEALL></a>]
		[<a href="<var $self>?admin=<var $admin>&amp;task=addip&amp;type=ipban&amp;ip=<var $ip>&amp;ipv6=<var $ipv6>" onclick="return do_ban(this)"><const S_MPBAN></a>]
	</td>

	</tr>
	<if $image>
		<tr class="row<var $rowtype>">
		<td colspan="6"><small>
		<const S_PICNAME><a href="<var expand_filename(clean_path($image))>"><var clean_string($image)></a>
		(<var $size> B, <var $width>x<var $height>)&nbsp; MD5: <var $md5>
		</small></td></tr>
	</if>
</loop>

</tbody></table>

<div class="delbuttons">
<input type="submit" value="<const S_MPDELETE>" />
<input type="submit" name="archive" value="<const S_MPARCHIVE>" />
<input type="reset" value="<const S_MPRESET>" />
[<label><input type="checkbox" name="fileonly" value="on" /><const S_MPONLYPIC></label>]
</div>

</form>

<br /><div class="postarea">

<form action="<var $self>" method="post">
<input type="hidden" name="task" value="deleteall" />
<input type="hidden" name="admin" value="<var $admin>" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><input type="text" name="mask" size="24" />
<input type="submit" value="<const S_MPDELETEIP>" /></td></tr>
</tbody></table></form>

</div><br />

<var sprintf S_IMGSPACEUSAGE,int($size/1024)>

}.NORMAL_FOOT_INCLUDE);




use constant BAN_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANABANS></div>

<div class="postarea">
<table><tbody><tr><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="task" value="addip" />
<input type="hidden" name="type" value="ipban" />
<input type="hidden" name="admin" value="<var $admin>" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><input type="text" name="mask" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANIP>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if !$parsedate and scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<if !$parsedate><small><const S_BANSECONDS></small></if>
</if>
</td></tr>
</tbody></table></form>

</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="task" value="addip" />
<input type="hidden" name="type" value="whitelist" />
<input type="hidden" name="admin" value="<var $admin>" />
<table><tbody>
<tr><td class="postblock"><const S_BANIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANMASKLABEL></td><td><input type="text" name="mask" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANWHITELIST>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if !$parsedate and scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<if !$parsedate><small><const S_BANSECONDS></small></if>
</if>
</td></tr>
</tbody></table></form>

</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td></tr><tr><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="task" value="addstring" />
<input type="hidden" name="type" value="wordban" />
<input type="hidden" name="admin" value="<var $admin>" />
<table><tbody>
<tr><td class="postblock"><const S_BANWORDLABEL></td><td><input type="text" name="string" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANWORD>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if !$parsedate and scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<if !$parsedate><small><const S_BANSECONDS></small></if>
</if>
</td></tr>
</tbody></table></form>

</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td valign="bottom">

<form action="<var $self>" method="post">
<input type="hidden" name="task" value="addstring" />
<input type="hidden" name="type" value="trust" />
<input type="hidden" name="admin" value="<var $admin>" />
<table><tbody>
<tr><td class="postblock"><const S_BANTRUSTTRIP></td><td><input type="text" name="string" size="24" /></td></tr>
<tr><td class="postblock"><const S_BANCOMMENTLABEL></td><td><input type="text" name="comment" size="16" />
<input type="submit" value="<const S_BANTRUST>" /></td></tr>
<tr><td class="postblock"><const S_BANEXPIRESLABEL></td><td>
<if !$parsedate and scalar BAN_DATES>
	<select name="expires">
		<loop BAN_DATES>
			<option value="<var $label>"><var clean_string($label)></option>
		</loop>
	</select>
<else>
	<input type="text" name="expires" size="16" />
	<if !$parsedate><small><const S_BANSECONDS></small></if>
</if>
</td></tr>
</tbody></table></form>

</td></tr></tbody></table>
</div><br />

<table align="center"><tbody>
<tr class="managehead"><const S_BANTABLE></tr>

<loop $bans>
	<if $divider><tr class="managehead"><th colspan="7"></th></tr></if>

	<tr class="row<var $rowtype>">

	<if $type eq 'ipban'>
		<td>IP</td>
		<td><if $date><var make_date($date, '2ch')></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td><var dec_to_dot($ival1,$sval1)></td><td><var dec_to_dot($ival2,$sval1)></td>
	</if>
	<if $type eq 'wordban'>
		<td>Word</td>
		<td><if $date><var make_date($date, '2ch')></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td colspan="2"><var $sval1></td>
	</if>
	<if $type eq 'trust'>
		<td>NoCap</td>
		<td><if $date><var make_date($date, '2ch')></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td colspan="2"><var $sval1></td>
	</if>
	<if $type eq 'whitelist'>
		<td>Whitelist</td>
		<td><if $date><var make_date($date, '2ch')></if></td>
		<td><if $expires><var make_date($expires, '2ch')><else><const S_BANEXPIRESNEVER></if></td>
		<td><var dec_to_dot($ival1)></td><td><var dec_to_dot($ival2)></td>
	</if>

	<td><var $comment></td>
	<td><a href="<var $self>?admin=<var $admin>&amp;task=removeban&amp;num=<var $num>"><const S_BANREMOVE></a></td>
	</tr>
</loop>

</tbody></table><br />

}.NORMAL_FOOT_INCLUDE);


use constant PROXY_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANAPROXY></div>
        
<div class="postarea">
<table><tbody><tr><td valign="bottom">

<if !ENABLE_PROXY_CHECK>
	<div class="dellist"><const S_PROXYDISABLED></div>
	<br />
</if>        
<form action="<var $self>" method="post">
<input type="hidden" name="task" value="addproxy" />
<input type="hidden" name="type" value="white" />
<input type="hidden" name="admin" value="<var $admin>" />
<table><tbody>
<tr><td class="postblock"><const S_PROXYIPLABEL></td><td><input type="text" name="ip" size="24" /></td></tr>
<tr><td class="postblock"><const S_PROXYTIMELABEL></td><td><input type="text" name="timestamp" size="24" />
<input type="submit" value="<const S_PROXYWHITELIST>" /></td></tr>
</tbody></table></form>

</td></tr></tbody></table>
</div><br />

<table align="center"><tbody>
<tr class="managehead"><const S_PROXYTABLE></tr>

<loop $scanned>
        <if $divider><tr class="managehead"><th colspan="6"></th></tr></if>

        <tr class="row<var $rowtype>">

        <if $type eq 'white'>
                <td>White</td>
	        <td><var $ip></td>
        	<td><var $timestamp+PROXY_WHITE_AGE-time()></td>
        </if>
        <if $type eq 'black'>
                <td>Black</td>
	        <td><var $ip></td>
        	<td><var $timestamp+PROXY_BLACK_AGE-time()></td>
        </if>

        <td><var $date></td>
        <td><a href="<var $self>?admin=<var $admin>&amp;task=removeproxy&amp;num=<var $num>"><const S_PROXYREMOVEBLACK></a></td>
        </tr>
</loop>

</tbody></table><br />

}.NORMAL_FOOT_INCLUDE);


use constant SPAM_PANEL_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div align="center">
<div class="dellist"><const S_MANASPAM></div>
<p><const S_SPAMEXPL></p>

<form action="<var $self>" method="post">

<input type="hidden" name="task" value="updatespam" />
<input type="hidden" name="admin" value="<var $admin>" />

<div class="buttons">
<input type="submit" value="<const S_SPAMSUBMIT>" />
<input type="button" value="<const S_SPAMCLEAR>" onclick="document.forms[0].spam.value=''" />
<input type="reset" value="<const S_SPAMRESET>" />
</div>

<textarea name="spam" rows="<var $spamlines>" cols="60"><var $spam></textarea>

<div class="buttons">
<input type="submit" value="<const S_SPAMSUBMIT>" />
<input type="button" value="<const S_SPAMCLEAR>" onclick="document.forms[0].spam.value=''" />
<input type="reset" value="<const S_SPAMRESET>" />
</div>

</form>

</div>

}.NORMAL_FOOT_INCLUDE);



use constant SQL_DUMP_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANASQLDUMP></div>

<div align="center">

<br />

<form action="<var $self>" method="get">
<input type="hidden" name="admin" value="<var $admin>" />
<input type="hidden" name="task" value="sqldump" />

<select name="table">
	<loop $tables>
		<option value="<var $table>"><var $table></option>
	</loop>
</select>

<input type="submit" value="<const S_SQLDUMP>" />

</form>

<br />

</div>

}.NORMAL_FOOT_INCLUDE);



use constant SQL_INTERFACE_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div class="dellist"><const S_MANASQLINT></div>

<div align="center">
<form action="<var $self>" method="post">
<input type="hidden" name="task" value="sql" />
<input type="hidden" name="admin" value="<var $admin>" />

<textarea name="sql" rows="10" cols="60"></textarea>

<div class="delbuttons"><const S_SQLNUKE>
<input type="password" name="nuke" value="<var $nuke>" />
<input type="submit" value="<const S_SQLEXECUTE>" />
</div>

</form>
</div>

<pre><code><var $results></code></pre>

}.NORMAL_FOOT_INCLUDE);




use constant ADMIN_POST_TEMPLATE => compile_template(MANAGER_HEAD_INCLUDE.q{

<div align="center"><em><const S_NOTAGS></em></div>

<div class="postarea">
<form id="postform" action="<var $self>" method="post" enctype="multipart/form-data">
<input type="hidden" name="task" value="post" />
<input type="hidden" name="admin" value="<var $admin>" />
<input type="hidden" name="no_captcha" value="1" />
<input type="hidden" name="no_format" value="1" />

<table><tbody>
<tr><td class="postblock"><const S_NAME></td><td><input type="text" name="field1" size="28" /></td></tr>
<tr><td class="postblock"><const S_EMAIL></td><td><input type="text" name="field2" size="28" /></td></tr>
<tr><td class="postblock"><const S_SUBJECT></td><td><input type="text" name="field3" size="35" />
<input type="submit" value="<const S_SUBMIT>" /></td></tr>
<tr><td class="postblock"><const S_COMMENT></td><td><textarea name="field4" cols="48" rows="4"></textarea></td></tr>
<tr><td class="postblock"><const S_UPLOADFILE></td><td><input type="file" name="file" size="35" />
[<label><input type="checkbox" name="nofile" value="on" /><const S_NOFILE> ]</label>
</td></tr>
<tr><td class="postblock"><const S_PARENT></td><td><input type="text" name="parent" size="8" /></td></tr>
<tr><td class="postblock"><const S_DELPASS></td><td><input type="password" name="password" size="8" /><const S_DELEXPL></td></tr>
</tbody></table></form></div><hr />
<script type="text/javascript">set_inputs("postform")</script>

}.NORMAL_FOOT_INCLUDE);


#
# Oekaki
#

# terrible quirks mode code
use constant OEKAKI_PAINT_TEMPLATE => compile_template(q{

<html>
<head>
<style type="text/css">
body { background: #9999BB; font-family: sans-serif; }
input,textarea { background-color:#CFCFFF; font-size: small; }
table.nospace { border-collapse:collapse; }
table.nospace tr td { margin:0px; } 
.menu { background-color:#CFCFFF; border: 1px solid #666666; padding: 2px; margin-bottom: 2px; }
</style>
</head><body>

<script type="text/javascript" src="palette_selfy.js"></script>
<table class="nospace" width="100%" height="100%"><tbody><tr>
<td width="100%">
<applet code="c.ShiPainter.class" name="paintbbs" archive="spainter_all.jar" width="100%" height="100%">
<param name="image_width" value="<var $oek_x>" />
<param name="image_height" value="<var $oek_y>" />
<param name="image_canvas" value="<var $oek_src>" />
<param name="dir_resource" value="./" />
<param name="tt.zip" value="tt_def.zip" />
<param name="res.zip" value="res.zip" />
<param name="tools" value="<var $mode>" />
<param name="layer_count" value="3" />
<param name="url_save" value="getpic.pl" />
<param name="url_exit" value="<var $self>?task=finish&amp;oek_parent=<var $oek_parent>&amp;oek_ip=<var $ip>&amp;srcinfo=<var $time>,<var $oek_painter>,<var $oek_src>" />
<param name="send_header" value="<var $ip>" />
</applet>
</td>
<if $selfy>
	<td valign="top">
	<script>palette_selfy();</script>
	</td>
</if>
</tr></tbody></table>
</body>
</html>
});


use constant OEKAKI_INFO_TEMPLATE => compile_template(q{
<p><small><strong>
Oekaki post</strong> (Time: <var $time>, Painter: <var $painter><if $source>, Source: <a href="<var $path><var $source>"><var $source></a></if>)
</small></p>
});


use constant OEKAKI_FINISH_TEMPLATE => compile_template(NORMAL_HEAD_INCLUDE.q{

[<a href="<var expand_filename(HTML_SELF)>"><const S_RETURN></a>]
<div class="theader"><const S_POSTING></div>

<div class="postarea">
<form id="postform" action="<var $self>" method="post" enctype="multipart/form-data">
<input type="hidden" name="task" value="oekakipost" />
<input type="hidden" name="oek_ip" value="<var $oek_ip>" />
<input type="hidden" name="srcinfo" value="<var $srcinfo>" />
<table><tbody>
<tr><td class="postblock"><const S_NAME></td><td><input type="text" name="field1" size="28" /></td></tr>
<tr><td class="postblock"><const S_EMAIL></td><td><input type="text" name="field2" size="28" /></td></tr>
<tr><td class="postblock"><const S_SUBJECT></td><td><input type="text" name="field3" size="35" />
<input type="submit" value="<const S_SUBMIT>" /></td></tr>
<tr><td class="postblock"><const S_COMMENT></td><td><textarea name="field4" cols="48" rows="4"></textarea></td></tr>

<if $image_inp>
	<tr><td class="postblock"><const S_UPLOADFILE></td><td><input type="file" name="file" size="35" />
	<if $textonly_inp>[<label><input type="checkbox" name="nofile" value="on" /><const S_NOFILE></label></if>
	</td></tr>
</if>

<if ENABLE_CAPTCHA and !$admin>
	<tr><td class="postblock"><const S_CAPTCHA></td><td><input type="text" name="captcha" size="10" />
	<img alt="" src="<var expand_filename(CAPTCHA_SCRIPT)>?key=<var get_captcha_key($thread)>&amp;dummy=<var $dummy>" />
	</td></tr>
</if>

<tr><td class="postblock"><const S_DELPASS></td><td><input type="password" name="password" size="8" /> <const S_DELEXPL></td></tr>

<if $oek_parent>
	<input type="hidden" name="parent" value="<var $oek_parent>" />
	<tr><td class="postblock"><const S_OEKIMGREPLY></td>
	<td><var sprintf(S_OEKREPEXPL,expand_filename(RES_DIR.$oek_parent.PAGE_EXT),$oek_parent)></td></tr>
</if>

<tr><td colspan="2">
<div class="rules">}.include("include/rules.html").q{</div></td></tr>
</tbody></table></form></div>
<script type="text/javascript">set_inputs("postform")</script>

<hr />

<div align="center">
<img src="<var expand_filename($tmpname)>" />
<var $decodedinfo>
</div>

<hr />

}.NORMAL_FOOT_INCLUDE);






no strict;
$stylesheets=get_stylesheets(); # make stylesheets visible to the templates
use strict;

sub get_filename($) { my $path=shift; $path=~m!([^/]+)$!; clean_string($1) }

sub show_filename($) {
	my ($filename)=@_;
	my ($name,$ext)=$filename=~/^(.*)(\.[^\.]+$)/;
	length($name)>25
		? clean_string(substr($name, 0, 25)."(...)$ext")
		: clean_string($filename);
}

sub get_stylesheets()
{
	my $found=0;
	my @stylesheets=map
	{
		my %sheet;

		$sheet{filename}=$_;

		($sheet{title})=m!([^/]+)\.css$!i;
		$sheet{title}=ucfirst $sheet{title};
		$sheet{title}=~s/_/ /g;
		$sheet{title}=~s/ ([a-z])/ \u$1/g;
		$sheet{title}=~s/([a-z])([A-Z])/$1 $2/g;

		if($sheet{title} eq DEFAULT_STYLE) { $sheet{default}=1; $found=1; }
		else { $sheet{default}=0; }

		\%sheet;
	} glob(CSS_DIR."*.css");

	$stylesheets[0]{default}=1 if(@stylesheets and !$found);

	return \@stylesheets;
}

1;

