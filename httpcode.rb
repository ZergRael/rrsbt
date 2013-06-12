require 'cgi'
class Httpcode
	def self.decode(str)
		type = "error"
		hash = {}

		request = str.match(/GET \/([\w\.]+)(\?.*)? HTTP/)
		if request
			type = request[1]
			unless request[2]
				return type
			end
			params = request[2].scan(/(?:[\?|&]([\w]+)=([\w~%\.\-\+]+))/)
			if params
				params.each do |p|
					if p[0] == "info_hash"
						infoHash = ""
						#log.debug "Got info_hash = #{p[1]}"
						infoHash = CGI::unescape(p[1]).unpack("H*")[0]
						#log.debug "Set info_hash = #{infoHash}"
						if type == "scrape"
							if !hash[p[0]]
								hash[p[0]] = []
							end
							hash[p[0]].push infoHash
						else
							hash[p[0]] = infoHash
						end
					elsif p[0] == "peer_id"
						hash[p[0]] = CGI::unescape(p[1])
					else
						hash[p[0]] = p[1]
					end
				end
			end
		end
		return type, hash
	end
	
	def self.encode(str)
		#Tue, 14 Dec 2010 10:48:45 GMT
		headers = "HTTP/1.1 200 OK\r\nDate: " + Time.now.asctime + "\r\nServer: RRSBT\r\nContent-Type: text/plain;\r\n\r\n"
		return headers + str
	end

	def self.webpage(title, str)
		#Tue, 14 Dec 2010 10:48:45 GMT
		headers = "HTTP/1.1 200 OK\r\nDate: " + Time.now.asctime + "\r\nServer: RRSBT\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n"
		html = "<html><head><title>#{title}</title></head><body>#{str}</body></html>"
		return headers + html
	end
	
	def self.err_404
		headers = "HTTP/1.1 200 OK\r\nDate: " + Time.now.asctime + "\r\nServer: RRSBT\r\nContent-Type: text/html;\r\n\r\n"
		html = "<html><head><title>Error 404 : Page not found</title></head><body><h1>Error 404 !</h1>Requested page cannot be found on this server. </body></html>"
		return headers + html
	end

	def self.torrent(str)
		#Tue, 14 Dec 2010 10:48:45 GMT
		headers = "HTTP/1.1 200 OK\r\nDate: " + Time.now.asctime + "\r\nServer: RRSBT\r\nContent-Type: application/x-bittorrent;\r\n\r\n"
		return headers + str
	end
end