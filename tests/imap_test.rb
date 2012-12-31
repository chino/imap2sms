#!/usr/bin/env ruby

require File.dirname(__FILE__) + "/test.lib"

def usage
	puts "Usage: ./#{__FILE__} <user> <pass>"
	exit 1
end

usage if $user.nil? or $pass.nil?

imap = ImapCache.new({
	:host  => $imap[:host],
	:user  => $imap[:user],
	:pass  => $imap[:pass],
	:db    => 'test.db',
	:debug => true
})

imap.update do |message|
	puts "Found new message: "+ message.inspect
end

File.delete "test.db"

