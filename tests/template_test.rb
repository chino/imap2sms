#!/usr/bin/env ruby
require File.dirname(__FILE__) + "/test.lib"

puts compile_template( $template, {
	:from        => "from_address",
	:to          => "sms_address",
	:subject     => "subject_line",
	:msg_from    => "msg_from",
	:msg_subject => "msg_subject",
	:msg_body    => "msg_body"
})

