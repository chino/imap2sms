#!/usr/bin/env ruby

##################################################################
# Settings
##################################################################

# temp vars for making it easy
$user,$pass,$alert,$norun = ARGV

$interval = 60 # seconds
$verbose  = true # print status messages

$imap = {
	:host => "imap.gmail.com",
	:user => $user,
	:pass => $pass,
	#:port  => 993,
	#:ssl   => true,
        #:debug => false # protocol debug
	:db => "#{ROOT}/cache.db"
}	

$smtp = {
	:host => 'smtp.gmail.com',
	:user => $user,
	:pass => $pass,
        :helo => "gmail.com",
	#:port  => 25,
	#:tls   => true,
        #:debug => false # protocol debug
}

$sms = {
	:address  => $alert,
	:ignore   => true, #false, # ignore emails from sms device ?
	:limit    => { # character limits
		:subject => 40,
		:body    => 160
	}
}

$template =<<TP
From: [[from]]
To: <[[to]]>
Subject: [[msg_subject]]

[[msg_from]] says, [[msg_body]]
TP

##################################################################
# Helpers
##################################################################

def usage
	puts "Usage: ./#{__FILE__} <user> <pass> <sms> [norun]"
	exit 1
end

def verbose str, nl = true
	print str, (nl ? "\n" : "") if $verbose
end

def clean str
	return "" if str.nil?
	str.
	gsub(/\s+/,' '). # reduce white space
	gsub(/(.)\1{3,}/m,'\1') # reduce 4|more repeated characters
end

def run_loop interval=1, startup=true, &block
	block.call if startup
	last_time = Time.now
	loop do
		time = Time.now - last_time
		unless time > interval
			sleep (interval - time)
			next
		end
		block.call
		last_time = Time.now
	end
end

def compile_template message, vars
	message = message.dup
	vars.each do |key,value|
		message = message.gsub("[[#{key.to_s}]]",value.to_s)
	end
	message = message.gsub(/\[\[[^\]]*?\]\]/,'')
end

require "openssl"
require "net/smtp"
def  email s # hash
	smtp = Net::SMTP.new( s[:host], s[:port] )
	smtp.set_debug_output $stdout if s[:debug]
	smtp.enable_starttls
	smtp = smtp.start( s[:helo], s[:user], s[:pass], :login )
	smtp.send_message s[:body], s[:user], s[:to]
	smtp.finish
end

def check_args
	usage if [$user,$pass,$alert].include?(nil)
end

##################################################################
# Script
##################################################################

check_args unless $norun

require 'imap_cache'
imap = ImapCache.new $imap

run_loop $interval do

	imap.update do |message|

		verbose "-"*50

		if $sms[:ignore] && message[:from_email] == $sms[:address]
			verbose "Ignoring email from sms device."
			next
		end

		from = message[:from].name || message[:from].mailbox
		
		body = compile_template( $template, {
			:from        => $smtp[:user],
			:to          => $sms[:address],
			:msg_from    => from,
			:msg_subject => clean( message[:subject] ).
					slice(0..($sms[:limit][:subject]-1)),
			:msg_body    => clean( message[:text] ).
					slice(0..($sms[:limit][:body]-1))
		})

                verbose body

		verbose "-"*50

#next

		email({
			:debug   => $smtp[:debug],
			:host    => $smtp[:host],
			:user    => $smtp[:user],
			:pass    => $smtp[:pass],
			:to      => $sms[:address],
			:body    => body
		})

	end

	verbose ".", false
	
end unless $norun

