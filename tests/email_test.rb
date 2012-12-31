#!/usr/bin/env ruby
require File.dirname(__FILE__) + "/test.lib"

$user,$pass,$sms = ARGV

body=<<STR

test
STR

puts body.length

email({
	:host    => $smtp[:host],
	:user    => $user,
	:pass    => $pass,
	:to      => $sms,
	:body    => body,
	:debug   => true,
})

