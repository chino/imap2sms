require 'rubygems'
require 'htmlentities'
require 'net/imap'
class ImapCache

	def initialize settings
		@host      = settings[:host]
		@port      = settings[:port] || 993
		@ssl       = settings[:ssl] || true
		@user      = settings[:user]
		@pass      = settings[:pass]
		@debug     = settings[:debug] || false
		@db        = settings[:db] || "cache.db"
		@connected = false
	end

	def connect
		return if @connected
		Net::IMAP.debug = @debug
		@imap = Net::IMAP.new( @host, @port, @ssl )
		@imap.capability
		@imap.login( @user, @pass )
		@connected = true
	end

	#
	# Check for Updates
	#
		
	def update &block
		connect
		@imap.examine('INBOX')
		@imap.uid_search(["UNSEEN"]).each do |message_uid|
			next if cached? message_uid
	
			save message_uid

			envelope = fetch( message_uid, "ENVELOPE" )
			message = {
				:from => envelope.from[0],
				:from_email => envelope.from[0]['mailbox'] + '@' + envelope.from[0]['host'],
				:subject => envelope.subject || "(no subject)",
				:text => get_body_text( message_uid )
			}

			yield message
		end
	end

	#
	# Helpers
	#

	def get_body_text message_uid
		body = fetch( message_uid, "BODYSTRUCTURE" )
		case body.media_type
		when "TEXT"
			# lots of bad people embed html in TEXT !
			strip_html fetch( message_uid, "BODY[TEXT]" )
		when "MULTIPART"
			case body.subtype
			when "ALTERNATIVE"

				i = body.parts.
					index{|part| part.subtype == 'PLAIN'}

				if i
					fetch(message_uid,"BODY[#{i + 1}]")
				else
puts "*** MULTIPART ALTERNATIVE: missing plain part"
					strip_html fetch(message_uid,"BODY[1]")
				end
			else
puts "*** MULTIPART #{body.subtype}: unknown"
				"MULTIPART #{body.subtype}: unknown"
			end
		else
puts "*** Unknown media_type #{body.media_type}"
			"Unknown media_type #{body.media_type}"
		end
	end

	def fetch message_uid, target
		@imap.uid_fetch( message_uid, target )[0].attr[ target ]
	end

	def strip_html html
		(@decoder ||= HTMLEntities.new).decode(html).
			gsub(/\s+/,' ').
			sub(/^.*<body>/,'').
			sub(/<\/body>.*$/,'').
			gsub(/<[^>]*>/,'')
	end

	#
	# DB Methods
	#

	def cache
		@cache ||= self.load
	end

	def cached? message_uid
		cache.include? message_uid
	end

	def save message_uid = nil
		cache << message_uid unless message_uid.nil?
puts "saved msg " + message_uid.to_s unless message_uid.nil?
		cache.sort.uniq
		file = File.open( @db, 'w+' )
		file.write cache.join("\n")
		file.close
	end

	def load
		@cache = (
			File.exists?(@db) && 
			File.read(@db).split("\n").map{|i| i.to_i }
		) || []
	end

end

