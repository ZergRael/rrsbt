class Torrent
	attr_accessor :info_hash, :clients, :nComplete, :nIncomplete, :nDownloaded

	def initialize(info_hash)
		@info_hash = info_hash
		@clients = {}
		@nComplete = 0
		@nIncomplete = 0
		@nDownloaded = 0
	end

	def setClient(c)
		@clients[c.peer_id] = c
		refreshData
	end

	def refreshData
		@nComplete, @nIncomplete = 0, 0
		clients.each do |k, c|
			@nIncomplete += (c.isLeech ? 1 : 0)
			@nComplete += (c.isLeech ? 0 : 1)
		end
	end

	def removeClient peer_id
		if @clients[peer_id]
			if (@clients[peer_id].isLeech == 1)
				@nIncomplete -= 1
			else
				@nComplete -= 1
			end
			@clients.delete(peer_id)
		end
	end
	
	def flushOldClients(timeStamp, maxInterval)
		clients.each do |k, c|
			if c.lastUpdate + maxInterval < timeStamp
				self.removeClient k
			end
		end
	end

	def getClientsArr(compact = false, numwant = 50)
		if compact
			clientsStr = ""
			i = 0
			clients.each do |k, c|
				if i >= numwant.to_i
					break
				end
				clientsStr += c.getHash(compact)
				i += 1
			end
			return clientsStr
		else
			clientsArr = []
			clients.each do |k, c|
				if clientsArr.length >= numwant.to_i
					break
				end
				clientsArr.push(c.getHash(compact))
			end
			return clientsArr
		end
	end

	def getHash
		return { 'complete' => @nComplete, 'downloaded' => @nDownloaded, 'incomplete' => @nIncomplete }
	end
end