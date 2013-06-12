class RData
	require 'yaml'
	require 'digest/sha1'
	attr_accessor :config, :torrents, :info_hashes
	def initialize
		configFile = "config.yml"
		@cPath = File.split($0)[0] + '/data/' + configFile
		torrentFile = "cache_torrent.yml"
		@tPath = File.split($0)[0] + '/data/' + torrentFile
		infoHashesFile = "info_hashes.yml"
		@iPath = File.split($0)[0] + '/data/' + infoHashesFile
	end

	def load
		unless File.exists? @cPath
			File.open(@cPath, 'w+') {|f| f.write(YAML::dump({})) }
		end
		@config = YAML::load_file(@cPath)
		load_config_defaults

		unless File.exists? @tPath
			File.open(@tPath, 'w+') {|f| f.write(YAML::dump({})) }
		end
		@torrents = YAML::load_file(@tPath)

		unless File.exists? @iPath
			File.open(@iPath, 'w+') {|f| f.write(YAML::dump({})) }
		end
		@info_hashes = YAML::load_file(@iPath)
	end

	def load_config_defaults
		option_default = {
			'tracker_id' => Digest::SHA1.hexdigest((Time.now.to_i * rand(1024)).to_s),
			'interval' => 300, 
			'port' => 6979,
			'pieceSize' => 512 * 1024,
			'tracker' => '',
			'torrentOutput' => ''
		}

		option_default.each do |k, v|
			unless @config[k]
				@config[k] = v
			end
		end
	end

	def getTorrentInfoData fileName
		#@info_hashes = YAML::load_file(@iPath)
		if info_hashes[fileName]
			return info_hashes[fileName]['info_hash'], info_hashes[fileName]['name'], info_hashes[fileName]['tracker']
		else
			return nil
		end
	end

	def setTorrentInfoData(fileName, info_hash, name, tracker)
		#@info_hashes = YAML::load_file(@iPath)
		@info_hashes[fileName] = {'info_hash' => info_hash, 'name' => name, 'tracker' => tracker}
		File.open(@iPath, 'w+') {|f| f.write(YAML::dump(@info_hashes)) }
	end

	def save
		File.open(@cPath, 'w+') {|f| f.write(YAML::dump(@config)) }
		File.open(@tPath, 'w+') {|f| f.write(YAML::dump(@torrents)) }
	end
end