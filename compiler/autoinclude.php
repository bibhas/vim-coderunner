<?php
	// Usage: autoinclude.php <c/c++/objc file>
	error_reporting(0);
	ini_set('display_errors', 0);
	$filename = $argv[1];
	$includes = array();
	
	$files = get_includes($filename);
	$headers = array("h", "hh", "hpp", "h++");
	$files = array_filter($files, function ($file) {
		global $headers;
		$extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));
		return !in_array($extension, $headers) && file_exists($file);
	});
	$files = array_values($files);
	$dirname = dirname($filename);
	for ($i = 0; $i < count($files); $i++) {
		if (dirname($files[$i]) == $dirname) {
			$files[$i] = pathinfo($files[$i], PATHINFO_BASENAME);
		}
	}
	echo implode(":", $files);

	function get_includes($filename, &$includes = false) {
		if (!$includes) {
			$includes = array($filename);
		}
		// Recurse through includes within this file
		foreach (includedFiles($filename) as $include) {
			if (!in_array($include, $includes)) {
				array_push($includes, $include);
				get_includes($include, $includes);
			}
		}
		// Look for implementation files
		$extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
		if (in_array($extension, array("h", "hh", "hpp", "h++"))) {
			$implementationExtensions = array("cpp", "cc", "cp", "cxx", "c++");
			if ($extension == "h") {
				$implementationExtensions = array_merge($implementationExtensions, array("c", "m", "mm"));
			}
			$directory = dirname($filename);
			$classname = pathinfo($filename, PATHINFO_FILENAME);
			$files = array_filter(scandir($directory), function($item) {
				return !is_dir($directory."/".$item);
			});
			foreach ($files as $file) {
				$theFile = pathinfo($file, PATHINFO_FILENAME);
				if ($theFile == $classname) {
					$theFileExt = strtolower(pathinfo($file, PATHINFO_EXTENSION));
					if (in_array($theFileExt, $implementationExtensions)) {
						$path = $directory."/".$file;
						if (!in_array($path, $includes)) {
							$includedFiles = includedFiles($path);
							if (in_array($filename, $includedFiles)) {
								array_push($includes, $path);
								foreach ($includedFiles as $include) {
									if (!in_array($include, $includes)) {
										array_push($includes, $include);
										get_includes($include, $includes);
									}
								}
								break;
							}
						}
					}
				}
			}
		}
		
		return $includes;
	}
	
	function includedFiles($filename) {
		if (!file_exists($filename)) {
			return array();
		}
		$file = file_get_contents($filename);
		if (!$file) {
			return array();
		}
		$file = strip_comments($file);
		$includes = array();
		if (preg_match_all('/^\s*#(include|import)\s+"([^"]+)"/m', $file, $matches)) {
			foreach ($matches[2] as $match) {
				if ($match[0] == "/" || $match[0] == "~") {
					$include = $match;
				} else {
					$include = dirname($filename)."/".$match;
				}
				$include = normalize_path($include);
				if (!$include) continue;
				array_push($includes, $include);
			}
		}
		return $includes;
	}
	
	function strip_comments($file) {
		$lineComment = -1;
		$blockComment = -1;
		for ($i = 0; $i < strlen($file); $i++) {
			if ($lineComment != -1) {
				if (substr($file, $i, 1) == "\n" || substr($file, $i, 1) == "\r") {
					$file = substr($file, 0, $lineComment).substr($file, $i+1);
					$i = $lineComment-1;
					$lineComment = -1;
				}
				continue;
			}
			if ($blockComment != -1) {
				if (substr($file, $i-1, 2) == "*/") {
					$file = substr($file, 0, $blockComment).substr($file, $i+1);
					$i = $blockComment-1;
					$blockComment = -1;
				}
				continue;
			}
			
			if ($i >= 1 && substr($file, $i-1, 2) == "//") {
				$lineComment = $i-1;
				continue;
			}
			if ($i >= 1 && substr($file, $i-1, 2) == "/*") {
				$blockComment = $i-1;
				continue;
			}
		}
		if ($lineComment != -1)  $file = substr($file, 0, $lineComment);
		if ($blockComment != -1)  $file = substr($file, 0, $blockComment);
		return $file;
	}
	
	function normalize_path($path) {
		$parts = preg_split(":[\\\/]:", $path);

		// resolve relative paths
		for ($i = 0; $i < count($parts); $i +=1) {
			if ($parts[$i] === "..") {
				if ($i === 0) {
					return false;
				}
				unset($parts[$i - 1]);
				unset($parts[$i]);
				$parts = array_values($parts);
				$i -= 2;
			} else if ($parts[$i] === ".") {
				unset($parts[$i]);
				$parts = array_values($parts);
				$i -= 1;
			}
			if ($i > 0 && $parts[$i] === "") {
				unset($parts[$i]);
				$parts = array_values($parts);
			}
		}
		return implode("/", $parts);
	}
