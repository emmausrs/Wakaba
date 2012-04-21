<?php
	/*
	 * PHP CGI Wrapper
	 *     by Frank Usrs
	 *
	 * This script is a wrapper for running CGI scripts through PHP. For
	 * help and support, consult the included README file and/or visit
	 * the GitHub project page:
	 *
	 * https://github.com/frankusrs/PHP-CGI-Wrapper
	 *
	 * This program is free software. It comes without any warranty, to
	 * the extent permitted by applicable law. You can redistribute it
	 * and/or modify it under the terms of the Do What The Fuck You Want
	 * To Public License, Version 2, as published by Sam Hocevar. See
	 * http://sam.zoy.org/wtfpl/COPYING for more details.
	 */

	ini_set('display_errors', true);

	define('MULTIPART_FORMAT', "%s\r\nContent-Disposition: form-data; name=\"%s\"");
	define('MULTIPART_TEXT_FORMAT', MULTIPART_FORMAT . "\r\n\r\n%s\r\n");
	define('MULTIPART_FILE_FORMAT', MULTIPART_FORMAT . "; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n%s\r\n");

	function escapequotes(&$string) {
		$string = str_replace('"', '\"', $string);
	}

	function execute_cgi($script)
	{
		// Set the proper environment variables if they aren't present.
		if (!isset($_ENV['REQUEST_METHOD']))
			foreach ($_SERVER as $var => $value)
				putenv("$var=$value"); // not sure if safe

		// Set cookies
		if (!isset($_ENV['HTTP_COOKIE']) && count($_COOKIE)) {
			$cookies = array();
			foreach ($_COOKIE as $name => $value)
				$cookies[] = urlencode($name).'='.urlencode($value);

			putenv(sprintf('HTTP_COOKIE=%s', implode('; ', $cookies)));
		}

		$ph = proc_open($script, array(
			array('pipe', 'r'), // STDIN
			array('pipe', 'w'), // STDOUT
		), $pipes);

		if ($_SERVER['REQUEST_METHOD'] == "POST") {
			/* Because PHP is a steaming pile of shit, you can't access the raw post data
			 * when using multipart/form-data encoding. Thus, we waste our PRECIOUS CPU
			 * CYCLES reconstructing the POST data manually. */
			if (preg_match('!^multipart/form-data; boundary=([^\s]+)!', $_SERVER['CONTENT_TYPE'], $matches)) {
				$boundary = '--' . $matches[1];

				foreach ($_POST as $name => $value) {
					escapequotes($name);
					fwrite($pipes[0], sprintf(MULTIPART_TEXT_FORMAT, $boundary, $name, $value));
				}

				foreach ($_FILES as $name => $file) {
					$error = $file['error'] === UPLOAD_ERR_OK ? false : true;
					$type = $error ? 'application/octet-stream' : $file['type'];
					$filename = $file['name'];

					escapequotes($name);
					escapequotes($filename);

					// maybe we should use some sort of buffer here instead of grabbing the whole file at once?
					fwrite($pipes[0], sprintf(MULTIPART_FILE_FORMAT, $boundary, $name, $filename, $type,
						$error ? '' : file_get_contents($file['tmp_name'])));
				}

				fwrite($pipes[0], "$boundary--\r\n");
			} else {
				// URL-encoded POST data
				fwrite($pipes[0], file_get_contents('php://input'));
			}
		}

		fclose($pipes[0]);

		// headers
		while (($line = fgets($pipes[1])) !== false && $line != "\n" && $line != "\r\n")
			header($line);

		// body
		while (($line = fgets($pipes[1])) !== false)
			echo $line;

		// and we're done
		fclose($pipes[1]);
		proc_close($ph);

		exit;
	}
?>
