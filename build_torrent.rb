#!/usr/bin/ruby1.9.1
class TorrentBuilder
	require_relative 'bencode'
	require_relative "rdata"
	require 'open-uri'
	require 'resolv'
	require 'digest/sha1'

	def echoError optionErr=''
		unless optionErr == ''
			print "build_torrent.rb : option invalide -- '#{optionErr}'\n"
		end
		print "usage:\t#{$0} [ -p { *K | *M } ] [ -t tracker_http ] [ -o torrent_output ] path\n"
		print "\tpath\trepertoire ou fichier a .torrent\n"
		print "\t-p\ttaille des pieces { *K | *M } = #{@rdata.config['pieceSize']}\n"
		print "\t-o\trepertoire de sortie du .torrent (en plus de ./torrent/) = #{@rdata.config['torrentOutput']}\n"
		print "\t-t\tpreciser le tracker utilise (devrait etre automatiquement deduit) = #{@rdata.config['tracker']}\n"
		print "Les options sont automatiquement sauvegardees pour un usage futur\n"
	end

	$lastTt = 0
	def writeProgress name, bytes, bytesTotal, fStart, totalBytes=false, totalBytesTotal=false, totalStart=false
		tt = Time.now.to_f
		if tt - $lastTt < 0.1
			return
		end
		$lastTt = tt

		percent = bytes.to_f/bytesTotal.to_f*100.0
		eta = 0
		if bytes != 0
			elapsed = (tt - fStart)
			eta = bytesTotal.to_f * elapsed / bytes.to_f - elapsed
		end

		if totalBytes
			percentTotal = totalBytes.to_f/totalBytesTotal.to_f*100.0
			etaTotal = 0
			if totalBytes != 0
				elapsed = (tt - totalStart)
				etaTotal = totalBytesTotal.to_f * elapsed / totalBytes.to_f - elapsed
			end

			print "\r\e[0K\e[1A\e[0K#{name} : #{bytes} / #{bytesTotal} (#{"%.2f" % percent}%) ETA : #{"%.2f" % eta}s\nTotal : #{totalBytes} / #{totalBytesTotal} (#{"%.2f" % percentTotal}%) ETA : #{"%.2f" % etaTotal}s"
		else
			print "\r\e[0K#{name} : #{bytes} / #{bytesTotal} (#{"%.2f" % percent}%) ETA : #{"%.2f" % eta}s"
		end
	end

	def goDeeper path, deep=[]
		#p "Going deeper #{path} ! #{deep}"
		files = []
		Dir.entries(path).each do |f|
			if f == '.' || f == '..'
				next
			end

			if File::file? (path + f)
				deepPath = Array.new(deep)
				file = {
					'length' => File.size(path + f),
					'path' => deepPath.push(f)
				}
				files.push(file)
			elsif File::directory? (path + f)
				deepPath = Array.new(deep)
				files.concat(goDeeper(path + f + '/', deepPath.push(f)))
			end
		end
		return files
	end

	def addTorrent path, pieceSize, tracker="", output = ""
		tt = Time.now.to_f

		if tracker == ""
			my_ip = open("http://checkip.dyndns.org/") { |f| /([0-9]{1,3}\.){3}[0-9]{1,3}/.match(f.read)[0] }
			unless my_ip
				p "Can't find my IP, aborting"
				return
			end
			my_hostname = Resolv::getname my_ip
			unless my_hostname
				p "Can't find my hostname, aborting"
				return
			end
			tracker = 'http://' + my_hostname + ':' + @rdata.config['port'].to_s + '/announce'
		end

		p "Starting analysis : '#{path}' tracked by '#{tracker}'."

		isDir = FileTest::directory? path
		isFile = FileTest::file? path

		unless isDir || isFile
			echoError path
			return
		end

		filePath, fileName = File.split(path)
		torrent = {
			'announce' => tracker,
			'creation date' => Time.now.to_i,
			'created by' => "RRSBT Torrent rebuilder",
			'info' => {}
		}

		totalLength = 0

		# FILE
		if isFile
			torrent['info'] = {
				'length' => File.size(path),
				'name' => fileName,
				'piece length' => pieceSize,
				'pieces' => "",
				'private' => 1
			}

			p "Torrent analysis ended : 1 file to hash."

			p "Starting hash with #{pieceSize}B pieces"
			print "\n"
			hash = ""
			piece = ""
			progress = 0
			totalLength = torrent['info']['length']
			hashStart = Time.now.to_f

			file = File.new(path)
			writeProgress(fileName, progress, totalLength, hashStart)
			while true
				piece += file.read(pieceSize)

				progress += (piece.length > totalLength ? totalLength : piece.length)
				writeProgress(fileName, progress, totalLength, hashStart)

				if piece.length == pieceSize
					hash += Digest::SHA1.digest(piece)
					piece = ""
				else
					break
				end
			end
			$lastTt = 0
			writeProgress(fileName, progress, totalLength, hashStart)
			print "\n"

			unless piece == ""
				hash += Digest::SHA1.digest(piece)
			end
			torrent['info']['pieces'] = hash

		# DIRECTORY
		else
			unless path.end_with? '/'
				path += '/'
			end
			torrent['info'] = {
				'files' => [],
				'name' => fileName,
				'piece length' => pieceSize,
				'pieces' => "",
				'private' => 1
			}

			torrent['info']['files'] = goDeeper(path)

			nFiles = 0
			torrent['info']['files'].each do |f|
				totalLength += f['length']
				nFiles += 1
			end
			p "Torrent analysis ended : #{nFiles} file#{nFiles > 1 ? 's' : ''} to hash."

			p "Starting hash with #{pieceSize}B pieces"
			print "\n"
			hash = ""
			piece = ""
			fileProgress = 0
			totalProgress = 0
			totalHashStart = Time.now.to_f

			torrent['info']['files'].each do |f|
				fileHashStart = Time.now.to_f
				file = File.new(path + f['path'].join('/'))

				writeProgress(f['path'].join('/'), fileProgress, f['length'], fileHashStart, totalProgress, totalLength, totalHashStart)
				while true
					lengthBefore = piece.length
					pieceTemp = file.read(pieceSize - piece.length)
					if pieceTemp != nil
						piece += pieceTemp
					end

					fileProgress += (piece.length - lengthBefore)#(piece.length > f['length'] ? f['length'] : piece.length)
					totalProgress += (piece.length - lengthBefore)
					writeProgress(f['path'].join('/'), fileProgress, f['length'], fileHashStart, totalProgress, totalLength, totalHashStart)

					if piece.length == pieceSize
						hash += Digest::SHA1.digest(piece)
						piece = ""
					else
						break
					end
				end
				$lastTt = 0
				writeProgress(f['path'].join('/'), fileProgress, f['length'], fileHashStart, totalProgress, totalLength, totalHashStart)
				fileProgress = 0
			end
			print "\n"

			unless piece == ""
				hash += Digest::SHA1.digest(piece)
			end
			torrent['info']['pieces'] = hash
		end

		#p torrent
		bEncoded = Bencode.encode(torrent)
		#p bEncoded

		torrentFileName = File.basename(path, (isFile ? File.extname(path) : '')) + "-RRSBT.torrent"
		torrentFile = File.open(File.split($0)[0] + '/torrents/' + torrentFileName, "w+")
		torrentFile.write(bEncoded)
		torrentFile.close()

		if output != ""
		  unless output.end_with? '/'
		    output += '/'
		  end
		  torrentFileCopy = File.open(output + torrentFileName, "w+")
		  torrentFileCopy.write(bEncoded)
		  torrentFileCopy.close()
		end

		tt2 = Time.now.to_f

		units = ["B", "KB", "MB", "GB", "TB"]
		unit = 0
		while totalLength >= 1024
			totalLength /= 1024.0
			unit += 1
		end

		speedUnit = unit
		speed = (totalLength / (tt2 - tt)).round(3)
		if speed < 1 && speedUnit > 0
			speed = (totalLength * 1024 / (tt2 - tt)).round(3)
			speedUnit -= 1
		end
		p "Hashing ended : #{totalLength.round(3)}#{units[unit]} in #{(tt2 - tt).round(2)}s = #{speed}#{units[speedUnit]}/s"

		info_hash = Digest::SHA1.hexdigest(Bencode.encode(torrent['info']))
		@rdata.setTorrentInfoData(torrentFileName, info_hash, fileName, tracker)
		p "Expected info_hash = #{info_hash}"
	end

	def initialize
		@rdata = RData.new
		if ARGV.length >= 1
			availableOptions = {'p' => 1, 't' => 1, 'o' => 1}
			options = {}
			ARGV.each do |a|
				if a[0,1] == '-'
					i = 1
					while i < a.length
						o = a[i,i]
						if availableOptions[o]
							options[o] = true
						else
							echoError o
							Process.exit
						end
						i += 1
					end
				else
					if options.length != 0 && availableOptions[options.keys.last] && availableOptions[options.keys.last] > 0 && options[options.keys.last] && options[options.keys.last] == true
						options[options.keys.last] = a
					else
						options['path'] = a
					end
				end
			end

			pieceSize = @rdata.config['pieceSize']
			if options['p']
				unless options['p'].is_a? String
					echoError "p"
					Process.exit
				end
				sizeUnit = options['p'].match(/(\d+)(K|M)/)
				if sizeUnit
					pieceSize = sizeUnit[1].to_i * 1024 * (sizeUnit[2] == 'M' ? 1024 : 1)
				else
					echoError "p"
					Process.exit
				end
			end

			tracker = @rdata.config['tracker']
			if options['t']
				tracker = options['t']
			end

			output = @rdata.config['torrentOutput']
			if options['o']
				output = options['o']
				unless FileTest::directory? output
					echoError "o"
					Process.exit
				end
			end

			path = options['path']
			@rdata.config['pieceSize'] = pieceSize
			@rdata.config['tracker'] = tracker
			@rdata.config['torrentOutput'] = output
			@rdata.save
			addTorrent(path, pieceSize, tracker, output)
		else
			echoError
		end
	end
end

TorrentBuilder.new