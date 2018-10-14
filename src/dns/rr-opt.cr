class DNS::Option
	enum Code
		None		= 0
		DAU		= 5
		DHU		= 6
		N3U		= 7
		COOKIE	= 10
	end
	property option_code : Code = Code::None
	property option_data : Bytes = Bytes.new(0)

	def encode( io : IO )
		io.write_network_short @option_code.to_i32
		io.write_network_short @option_data.size
		io.write @option_data.to_slice
	end
	def inspect( io : IO )
		io << "#<DNS::Option::"
		io << option_code
		io << " option_data=#{option_data.inspect}"
		io << ">"
	end
end

class DNS::RR::OPT < DNS::RR
	property options : Array(DNS::Option) = [] of DNS::Option

	def extended_rcode()
		( @ttl >> 24 ) & 0xFF
	end
	def extended_rcode=( val )
		@ttl = ( @ttl & 0x00FFFFFF ) | ( ( val & 0xFF ) << 24 )
	end

	def version()
		( @ttl >> 16 ) & 0xFF
	end
	def version=( val )
		@ttl = ( @ttl & 0xFF00FFFF ) | ( ( val & 0xFF ) << 16 )
	end

	def udp_payload_size()
		@cls.to_u16
	end
	def udp_payload_size=( value )
		@cls = DNS::RR::Cls.new(value.to_i32)
	end

	def accept_dnssec()
		(@ttl & 0x8000) == 0x8000
	end
	def accept_dnssec=( val )
		if val
			@ttl |= 0x00008000
		else
			@ttl &= 0xFFFF7FFF
		end
	end

	def initialize()
		@type = DNS::RR::Type::OPT
	end
	def encode( io : IO )
		encode_options
		super
	end
	def encode_options()
		io = IO::Memory.new
		@options.each {|opt| opt.encode(io) }
		@raw_data = io.to_slice
	end

	def decode_options()
		flags = @ttl & 0xFFFF
		return if @raw_data.size == 0

		io = IO::Memory.new(@raw_data.to_slice)


		#return
		
		while io.pos <= ( io.size - 4 )
			puts "io.pos=#{io.pos}, io.size=#{io.size}"
			opt = DNS::Option.new
			opt.option_code = DNS::Option::Code.new(io.read_network_short.to_i32)
			puts "opt.option_code = #{opt.option_code}"
			size = io.read_network_short()
			data = Bytes.new(size)
			if !(io.read_fully?(data)).nil?
				opt.option_data = data
				@options.push(opt)
			else
				raise "Error decoding option"
			end
		end
	end

	def inspect( io : IO )
		io << "#<DNS::RR::OPT"
		io << " udp_payload_size=" << udp_payload_size
		io << " extended_rcode=" << extended_rcode
		io << " version=" << version
		io << " accept_dnssec=" << accept_dnssec

		options.each {|o|
			io << " "
			o.inspect(io)
		}

		io << ">"
	end
end