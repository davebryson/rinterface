require 'lib/rinterface'


# Example of connecting to an Erlang node and making an RPC call
include Erlang

EM.run do
  # Connect to epmd to get the port of 'math'. 'math' is the -sname of the erlang node
  epmd = EpmdConnection.lookup_node("math")
  epmd.callback do |port|
    puts "got the port #{port}"
    
    # make the rpc call to 'math' on port for mod 'math_server' on fun 'add' with args
    node = Node.rpc_call("math",port.to_i,"math_server","add",[10,20])
    node.callback{ |result|
      puts "Sum is: #{result}"
      EM.stop
    }
    
    node.errback{ |err|
      puts "Error: #{err}"
      EM.stop
    }
  end
  
  epmd.errback do |err|
    puts "Error: #{err}"
    EM.stop
  end
end

