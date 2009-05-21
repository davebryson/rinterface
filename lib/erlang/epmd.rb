#
# Connects to epmd to find the port number of the requested node
# this only implements port_please_request
#
module Erlang
  class EpmdConnection < EM::Connection
    include EM::Deferrable
    attr_accessor :nodename
  
    def self.lookup_node(nodename)
      EM.connect("127.0.0.1",4369,self) do |conn|
        conn.nodename = nodename
      end
    end
  
    def connection_completed
      send_data lookup_port
    end
  
    def receive_data(data)
      parse_response(data)
    end
  
    def unbind
    end
  
    def lookup_port
      out = StringIO.new('', 'w')
    
      # Create the header with length: 2
      out.write([@nodename.size + 1].pack('n'))
    
      # Next the request
      # tag. Length: 1
      out.write([122].pack("C"))
      # nodename
      out.write(nodename)
      out.string
    end
  
    # If we get a good result we only return 
    # the port (not reading all the information
    def parse_response(input)
      i = StringIO.new(input)
      code = i.read(1).unpack('C').first
      result = i.read(1).unpack('C').first
      if result == 0
        # good response read the port
        port = i.read(2).unpack('n').first
        set_deferred_success port
      else
        set_deferred_failure 0
      end
    end
    
  end
end

