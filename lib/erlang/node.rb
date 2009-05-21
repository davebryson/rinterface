# 
# Single shot client.
# - connects to epmd to get the port number of the erlang node
# - does the handshake
# - makes the RPC call
#
module Erlang
  class Node < EM::Connection
    include EM::Deferrable
    
    attr_accessor :host,:myname,:destnode,:port,:cookie,:mod,:fun,:args
    
    # node = destination node
    # port = the port of the Erlang node (from epmd)
    # mod  = the module to call
    # fun  = the function to call
    # args = args to pass to fun
    def self.rpc_call(node,port,mod,fun,args)
      EM.connect("127.0.0.1",port,self) do |c|
        c.destnode = node
        c.mod = mod
        c.fun = fun
        c.args = args
        c.port = port
        c.myname = build_nodename
        c.cookie = get_cookie
      end
    end
    
    # Get the Cookie from the home directory
    def self.get_cookie
      # ... I did it all for the cookie, come on the cookie ...
      fp = File.expand_path("~#{ENV['USER']}/.erlang.cookie")
      fh = File.open(fp,'r')
      fh.readline.strip
    end
    
    # Build a nodename for us
    def self.build_nodename
      require 'socket'
      myhostname = Socket.gethostname.split(".")[0]
      "ruby_client@#{myhostname}"
    end
    
    def post_init
      @responder = :determine_message
    end
    
    def connection_completed
      send_data send_name
    end
    
    def receive_data data
      @resp = data
      send @responder
    end
    
    def handle_any_response
      result = ""
      decoder = Decode.read_bits(@resp)
      s = decoder.read_4
      #puts "Size: #{s}"
      code = decoder.read_string(1)
      if code == 'p'
        #puts "found the p"
        # read the control message and ignore
        decoder.read_any 
        # read the message
        result = decoder.read_any
        puts "Raw Response: #{result.inspect}"
      else
        result = decoder.read_any
      end
      set_deferred_success result[1]
    end
    
    def send_name
      full_host_name = self.myname
      encode = Encoder.new
      encode.write_2(full_host_name.length + 7)
      # node type
      encode.write_1(110)
      # distChoose
      encode.write_2(5)
      # flags
      encode.write_4(4|256|1024|2048)
      # node name
      encode.write_string(full_host_name)
      encode.out.string
    end
    
    def determine_message
      decoder = Decode.read_bits(@resp)
      packet_size = decoder.read_2
      #puts "PacketSize: #{packet_size}"
      status_code = decoder.read_string(1)
      case status_code
      when 's' then receive_status(packet_size,decoder)
      when 'n' then receive_challenge(packet_size,decoder)
      when 'a' then receive_challenge_ack(packet_size,decoder)
      else "Got back a weird packet"
      end
    end
    
    def receive_status(packet_size,decoder)
      status = decoder.read_string(packet_size-1)
      if decoder.in.size > (packet_size + 2)
        # Hack when both receive packets are crammed together into 1
        next_packet_size = decoder.read_2 # read size
        status_code = decoder.read_string(1)
        receive_challenge(next_packet_size, decoder)
      end
      set_deferred_failure "Failed on Recv Status: #{status_code}" unless status == 'ok'
    end
    
    def receive_challenge(packet_size,decoder)
      dist_code = decoder.read_2
      #puts "Code: #{dist_code}"
      flags = decoder.read_4
      #puts "Flags #{flags}"
      challenge = decoder.read_4
      his_name = decoder.read_string(decoder.in.size-13)
      #puts "His name: #{his_name}"
      #puts "Got the challenge #{challenge}"
      #out_challenge = make_challenge(challenge)
      send_data make_challenge(challenge)
    end
    
    def make_challenge(her_challenge)
      incr_digest = Digest::MD5.new()
      incr_digest << @cookie
      incr_digest << her_challenge.to_s
      digest = incr_digest.digest
      our_challenge = rand(10000)
      encoder = Encoder.new
      encoder.write_2(21)
      encoder.write_string('r')
      encoder.write_4(our_challenge)
      encoder.write_string(digest)
      encoder.out.string
    end
    
    def receive_challenge_ack(packet_size,decoder)
      @responder = :handle_any_response
      call_remote
    end
    
    def call_remote
      myPid = Erlang::Terms::Pid.new(self.myname.intern,5,5,5)
      call_tuple = [:call,self.mod.intern,self.fun.intern,Erlang::Terms::List.new(self.args),:user]
      rpc_tuple  = [myPid,call_tuple]
      ctl_msg = [6,myPid,self.cookie.intern,:rex]

      encode_data = Encoder.new
      encode_data.term_to_binary(ctl_msg)
      encode_data.term_to_binary(rpc_tuple)
      data = encode_data.out.string
      
      f = Encoder.new
      f.write_4(data.length + 1)
      final_out = f.out.string + 'p' + data
      send_data final_out
    end
    
  end
end




