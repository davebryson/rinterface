require 'lib/rinterface'


# Try different responses...

# Bad rpc. Try to call the wrong service
r = Erlang::Node.rpc("math","matx_server","add",[10,20])
puts "Got: #{r.inspect}"

puts "--------"
# No Port for Service. Can't find a port for 'ath'
r = Erlang::Node.rpc("ath","matx_server","add",[10,20])
puts "Got: #{r.inspect}"

puts "--------"
# Good call
r = Erlang::Node.rpc("math","math_server","add",[10,20])
puts "Got: #{r.inspect}"

