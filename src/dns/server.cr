require "socket"

class DNS::Server
	class Request
		property message : DNS::Message = DNS::Message.new()
		property remote_address : Socket::IPAddress?
		property socket : Socket?

		def initialize()
		end
		def initialize( @remote_address )
		end
	end
	abstract class Listener
		property request_channel = Channel(Request).new()
		property response_channel = Channel(Request).new()

		abstract def get_request() : Request?
		abstract def send_response( req : Request )

		def run()
			puts "Starting listener loop"
			spawn do
				loop {
					begin
						# Get the request
						if !(req=get_request()).nil?
							# Send to the main thread to process
							@request_channel.send(req)
						end
					rescue e
						# Report server error
						puts "Caught error: #{e}"
						if req
							req.message.response_code = DNS::Message::ResponseCode::ServerFailure
							send_response(req)
						end
					end
				}
			end
			spawn do
				loop {
					res = @response_channel.receive
					send_response(res)
				}
			end
		end
	end

	class TCPListener < Listener
		@socket : TCPSocket

		def initialize(@socket)
		end

		def get_request() : Request?
			if !(s=@socket.accept?).nil?
				req = Request.new()
				req.socket = s
				return req
			end
			return nil
		end
		def send_response( req : Request )
			if !(sock=req.socket).nil?
				sock.send( req.message.encode() )
			end
		end
	end
	class UDPListener < Listener
		@socket : UDPSocket
		@buffer = Bytes.new(4096)
		def initialize(@socket)
		end

		def get_request() : Request?
			size,addr = @socket.receive(@buffer)
			puts "Received request:"
			puts @buffer[0,size].inspect

			# Create a new request
			req = Request.new(addr)
			req.message = DNS::Message.decode(@buffer[0,size])
			req.remote_address = addr

			return req
		end
		def send_response( req : Request )
			if !(ra=req.remote_address).nil?
				response = req.message.encode()
				puts "sending response: #{response}"
				puts req.message.inspect
				@socket.send( response, ra )
			else
				puts "Unable to send request, no remote address #{req.remote_address}"
			end
		end
	end

	@listeners = [] of Listener

	def initialize( udp_addr = "localhost", udp_port = 56, tcp_addr = "localhost", tcp_port = 53 )
		# Setup UDP listener
		l = UDPListener.new(sock=UDPSocket.new)
		sock.bind( udp_addr, udp_port )
		@listeners.push(l)

		# Setup TCP listener
		l = TCPListener.new(TCPServer.new( tcp_addr, tcp_port ))
		@listeners.push(l)
	end
	def run()
		# Startup fibers for each listener
		@listeners.each {|l| l.run }

		# event processing loop
		puts "Entering event processing loop"
		loop do
			@listeners.each {|l|
				while !l.request_channel.empty?
					req = l.request_channel.receive
					puts "Processing request #{req.message}"
					process_request(req)
					l.response_channel.send(req)
				end
			}
			sleep 0.1
		end
	end

	def process_request( req : Request )
		rr = DNS::RR.new(DNS::RR::A)
		rr.name = req.message.questions[0].name
		rr.data = "127.0.0.1"
		req.message.answers.push(rr)
		puts req.inspect
	end
end

