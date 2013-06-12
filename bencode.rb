class Bencode
	def self.encode(obj)
		return self.ben_encode(obj)
	end

	def self.decode(obj)
		return self.ben_decode(obj)[0]
	end
	
	protected
	
	def self.ben_encode(obj)
		#puts "Encode process : #{obj}"
		case obj
		when Integer
			return bInteger_encode(obj)
		when Array
			return bList_encode(obj)
		when Hash
			return bDictionnary_encode(obj)
		when String
			return bString_encode(obj)
		else
			puts "Err"
		end
	end

	def self.ben_decode(str)
		#puts "Decode process : #{str}"
		first_letter = str[0]
		case first_letter
		when "i"
			return bInteger_decode(str)
		when "l"
			return bList_decode(str)
		when "d"
			return bDictionnary_decode(str)
		else
			return bString_decode(str)
		end
	end

	private

	def self.bInteger_encode(int)
		#puts "Integer !"
		return "i" + int.to_s + "e"
	end

	def self.bList_encode(list)
		#puts "List !"
		str = ""
		list.each { |v| str += ben_encode(v) }
		return "l" + str + "e"
	end

	def self.bDictionnary_encode(dic)
		#puts "Dictionnary !"
		str = ""
		dic.each { |k, v| str += ben_encode(k) + ben_encode(v) }
		return "d" + str + "e"
	end

	def self.bString_encode(str)
		#puts "String !"
		str = str.dup.force_encoding("ISO-8859-1")
		return str.length.to_s + ":" + str
	end

	def self.bString_decode(str)
		bString = str.split(':', 2)
		nLetters = bString[0]
		string = bString[1][0,(nLetters.to_i)]
		size = (nLetters + string).length + 1
		#puts "String ! #{nLetters} : #{string} [#{size}]"
		return string, size
	end

	def self.bInteger_decode(str)
		#puts "Integer !"
		bInt = str[1..-1].split('e', 2)
		return bInt[0].to_i, bInt[0].length + 2
	end

	def self.bList_decode(str)
		#puts "List !"
		i = 1
		arr = []
		while str[i] != "e"
			#print "L:v "
			v, iAdd = ben_decode(str[i..-1])
			i += iAdd
			arr.push(v)
		end
		return arr, i + 1
	end

	def self.bDictionnary_decode(str)
		#puts "Dictionnary !"
		i = 1
		dic = {}
		while str[i] != "e"
			#print "D:k "
			k, iAdd = ben_decode(str[i..-1])
			i += iAdd
			#print "D:v "
			v, iAdd = ben_decode(str[i..-1])
			i += iAdd
			dic[k] = v
		end
		return dic, i + 1
	end
end