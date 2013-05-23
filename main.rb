require_relative "bencode"
require_relative "httpcode"
require_relative "torrent"
require_relative "client"
require_relative "rdata"
require 'socket'
require 'logger'
require 'cgi'


tt = Time.now
log = Logger.new("logs/rrsbt.log")
log.level = Logger::DEBUG
log.info "Starting RRSBT @ #{tt}"

log.debug "Loading data"
rdata = RData.new()
rdata.load
torrents = rdata.torrents
log.debug "Updating torrent data"
torrents.each do |ih, t|
	unless t.clients
		next
	end
	t.flushOldClients(tt.to_i, rdata.config['interval'] * 2)
end

begin
	a = TCPServer.new('', rdata.config['port'])
	log.info "Listening on #{rdata.config['port']}"
	loop {
		log.debug "Waiting new"
		connection = a.accept
		str = connection.recv(1024)

		#log.debug "Pure HTTP data = #{str}"
		tt = Time.now
		log.debug "Got HTTP GET : #{str}"
		request, data = Httpcode.decode(str)
		log.debug "HTTP_GET_Decoded_data: #{request} = #{data}"

		httpData = ""
		case request

		# ANNOUNCE
		when "announce"
			#info_hash, peer_id, port, uploaded, downloaded, left, compact, no_peer_id, event (started, completed, stopped), ip, numwant, key, trackerid
			# key is still not processed, do we really need to keep track of individual stats ?
			info_hash = data['info_hash']
			peer_id = data['peer_id']

			t = torrents[info_hash]
			# Creating torrent info if necessary
			if(! t)
				log.info "Torrent: New info_hash = #{info_hash}"
				t = Torrent.new(info_hash)
			end

			c = t.clients[peer_id]
			if(! c)
				log.info "Client: New peer_id = #{peer_id}"
				ip = (data['ip'] ? data['ip'] : connection.peeraddr[3])
				port = data['port'].to_i
				c = Client.new(peer_id, ip, port)
			end

			deleteMe = false
			# Event management
			if data['event']
				if data['event'] == "started"
					log.debug "Client[#{peer_id}]: Started !"
					# Do not care
				elsif data['event'] == "completed"
					log.debug "Client[#{peer_id}]: Completed !"
					t.nDownloaded += 1
				elsif data['event'] == "stopped"
					log.debug "Client[#{peer_id}]: Stopped !"
					deleteMe = true
				end
			end

			# Refreshing data
			c.isLeech = data['left'].to_i != 0
			c.refreshData
			#log.debug "Client = #{c.to_s}"
			t.setClient(c)

			response = {
				#'failure reason' => ,
				#'warning message' => ,
				'interval' => rdata.config['interval'], 
				'min interval' => rdata.config['interval']/2, 
				'tracker id' => (data['tracker id'] ? data['tracker id'] : rdata.config['tracker_id']), 
				'complete' => t.nComplete, 
				'incomplete' => t.nIncomplete, 
				'peers' => t.getClientsArr(data['compact'] && data['compact'].to_i == 1, data['numwant'])
			}

			# Flushing old clients
			t.flushOldClients(tt.to_i, rdata.config['interval'] * 2)

			if deleteMe
				t.removeClient(peer_id)
			end

			log.debug "Torrent : Stats after flushing #{t.getHash}"
			#log.debug "Torrent: #{t.to_s}"
			torrents[info_hash] = t

			log.debug "Response: #{response}"
			returnData = Bencode.encode(response)
			#log.debug "Encoded response: #{returnData}"
			httpData = Httpcode.encode(returnData)

		# SCRAPE
		when "scrape"
			response = { 'files' => {}}
			# [info_hash]

			if data and data['info_hash']
				data['info_hash'].each do |info_hash|
					if torrents[info_hash]
						response['files'][[info_hash].pack('H*')] = torrents[info_hash].getHash
					else
						response['files'][[info_hash].pack('H*')] = { 'complete' => 0, 'downloaded' => 0, 'incomplete' => 0 }
					end
				end
			end

			log.debug "Response: #{response}"
			returnData = Bencode.encode(response)
			log.debug "Encoded response: #{returnData}"
			httpData = Httpcode.encode(returnData)

		# TORRENTS
		when "torrents"
			tt_t = Time.now.to_f
			returnData = "<table><tr><th>Torrent</th><th>info_hash</th><th>Magnet link</th><th>Stats</th></td>"
			torrentFiles = Dir.entries("torrents")
			log.debug "Building torrents list"
			torrentFiles.each do |t|
				unless t.index('.torrent')
					next
				end

				info_hash, torrentName, torrentTracker = rdata.getTorrentInfoData t
				unless info_hash
					log.debug "Calculating info_hash for #{t}"
					f = File.open("torrents/" + t, "rb").read
					decodedData = Bencode.decode(f)
					info_hash = Digest::SHA1.hexdigest(Bencode.encode(decodedData['info']))
					torrentName = decodedData["info"]["name"]
					torrentTracker = decodedData["announce"]
					rdata.setTorrentInfoData(t, info_hash, decodedData["info"]["name"], decodedData["announce"])
				end

				log.debug "Got info_hash #{info_hash}"
				returnData += "<tr><td><a download=\"#{t}\" href=\"download?file=#{CGI::escape(t)}\">#{t}</a></td>"        
				returnData += "<td>#{info_hash}</td>"
				if torrents[info_hash]
					returnData += "<td><a href=\"magnet:?xt=urn:btih:#{info_hash}&dn=#{CGI::escape(torrentName)}&tr=#{CGI::escape(torrentTracker)}\">Magnet link</a></td>"
					returnData += "<td>Seeds : #{torrents[info_hash].nComplete} / Peers : #{torrents[info_hash].nIncomplete} / Downloaded : #{torrents[info_hash].nDownloaded}</td>"
				else
					returnData += "<td>Nope</td><td>Currently not tracked here</td>"
				end

				returnData += "</tr>\n"
				#magnet:?xt=urn:btih:91f66bfa54044f32e2bf23262ab0d01b34e787d1&dn=Dexter+S07E04+HDTV+x264-ASAP+%5Beztv%5D&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A80
			end

			returnData += "</table><br /><br />Generated in #{(Time.now.to_f - tt_t).round(3)}s"
			log.debug "Encoded response: #{returnData}"
			httpData = Httpcode.webpage("Torrents download page", returnData)

		# DOWNLOAD TORRENT FILE
		when "download"
			if data['file']
				torrent = CGI::unescape(data['file'])
				log.info "Requested torrent = #{torrent}"
				if Dir.entries("torrents").index(torrent) && File::file?('torrents/' + torrent)
					log.info "Sending torrent = #{torrent}"
					returnData = File.open('torrents/' + torrent, "rb").read
					#log.debug "Encoded response: #{returnData}"
					httpData = Httpcode.torrent(returnData)
				end
			else
				log.debug "Web : Returning 404"
				httpData = Httpcode.err_404
			end

		# OTHER REQUESTS
		else
			log.debug "Web : Returning 404"
			httpData = Httpcode.err_404
		end

		connection.write httpData
		connection.close
	}
rescue => err
	log.fatal "Caught exception ! Exiting."
	log.fatal err
ensure
	log.info "Stopping RRSBT"
	rdata.torrents = torrents
	rdata.save
	log.debug "Conf saved. EOO"
	log.close
end