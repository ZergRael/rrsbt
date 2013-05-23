class Client
	attr_accessor :peer_id, :ip, :port, :isLeech, :lastUpdate

	def initialize(peer_id, ip, port)
		@peer_id = peer_id
		@ip = ip
		@port = port
	end

	def refreshData
		@lastUpdate = Time.now.to_i
	end

	def getHash compact
		if compact
			str = ""
			ip.split('.').each do |i|
				str += i.to_i.chr
			end
			str += (port.to_i / 256).chr + (port.to_i % 256).chr
			return str
		else
			return { 'peer id' => peer_id, 'ip' => ip, 'port' => port }
		end
	end
end