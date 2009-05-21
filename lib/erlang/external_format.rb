#
# adopted from Erlectricity
# this version is slightly tweaked,  a bit sloppy, and needs a cleanin'
#
module Erlang
  module Terms
    
    class Pid
      attr_reader :node, :node_id, :serial, :creation
      def initialize(node,nid,serial,created)
        @node = node
        @node_id = nid
        @serial = serial
        @creation = created
      end
    end
    
    class List
      attr_reader :data
      def initialize(array)
        @data = array
      end
    end
    
  end
  
  module External
    module  Types
      SMALL_INT = 97
      INT = 98

      SMALL_BIGNUM = 110
      LARGE_BIGNUM = 111

      FLOAT = 99

      ATOM = 100
      REF = 101           #old style reference
      NEW_REF = 114     
      PORT = 102          #not supported accross node boundaries
      PID = 103

      SMALL_TUPLE = 104
      LARGE_TUPLE = 105

      NIL = 106
      STRING = 107
      LIST = 108
      BIN = 109
      
      FUN = 117
      NEW_FUN = 112
    end

    VERSION = 131
    
    MAX_INT = (1 << 27) -1
    MIN_INT = -(1 << 27)
    MAX_ATOM = 255
  end
  
  class Encoder
    include External::Types
    include Terms
    
    attr_accessor :out
    def initialize
      @out = StringIO.new('', 'w')
    end
    
    def rewind
      @out.rewind
    end
    
    def term_to_binary obj
      write_1 External::VERSION
      write_any_raw obj
    end
    
    def write_any_raw obj
      case obj
      when Symbol then write_symbol(obj)
      when Fixnum, Bignum then write_fixnum(obj)
      when Array then write_tuple(obj)
      when String then write_binary(obj)
      when Pid then write_pid(obj)
      when List then write_list(obj)
      else
        raise "Failed encoding!"
      end
    end
    
    def write_1(byte)
      @out.write([byte].pack("C"))
    end
    
    def write_2(short)
      @out.write([short].pack("n"))
    end
    
    def write_4(long)
      @out.write([long].pack("N"))
    end
    
    def write_string(string)
      @out.write(string)
    end
    
    def write_symbol(sym)
      data = sym.to_s
      write_1 ATOM
      write_2 data.length
      write_string data
    end
    
    #Only handles numbers < 256
    def write_fixnum(num)
      write_1 SMALL_INT
      write_1 num
    end
    
    def write_tuple(data)
      if data.length < 256
        write_1 SMALL_TUPLE
        write_1 data.length
      else
        write_1 LARGE_TUPLE
        write_4 data.length
      end
      data.each{|e| write_any_raw e }
    end
    
    def write_pid(pid)
      write_1(103)
      write_symbol(pid.node)
      write_4((pid.node_id & 0x7fff))
      write_4((pid.serial & 0x1fff))
      write_1((pid.creation & 0x3))
    end
    
    def write_list(list)
      len = list.data.size
      write_1(108)
      write_4(len)
      list.data.each{ |i| write_any_raw i }
      write_1(106)
    end
    
    def write_binary(data)
      write_1 BIN
      write_4 data.length
      write_string data
    end
    
  end
  
  class Decode
    include External::Types
    
    attr_accessor :in
    
    def self.read_bits(string)
      new(StringIO.new(string))
    end
    
    def self.read_any_from(string)
      new(StringIO.new(string)).read_any
    end
  
    def initialize(ins)
      @in = ins
      @peeked = ""
    end
  
    def read_any
      raise "Bad Math on Version" unless read_1 == External::VERSION
      read_any_raw
    end
  
    def read_any_raw
      case peek_1
      when ATOM then read_atom
      when SMALL_INT then read_small_int
      when INT then read_int
      when SMALL_BIGNUM then read_small_bignum
      when LARGE_BIGNUM then read_large_bignum
      when FLOAT then read_float
      when NEW_REF then read_new_reference
      when PID then read_pid
      when SMALL_TUPLE then read_small_tuple
      when LARGE_TUPLE then read_large_tuple
      when NIL then read_nil
      when STRING then read_erl_string
      when LIST then read_list
      when BIN then read_bin
      else
        fail("Unknown term tag: #{peek_1}")      
      end
    end
  
    def read(length)
      if length < @peeked.length
        result = @peeked[0...length]
        @peeked = @peeked[length..-1]
        length = 0
      else
        result = @peeked
        @peeked = ''
        length -= result.length
      end
    
      if length > 0
        result << @in.read(length)
      end
      result
    end
  
    def peek(length)
      if length <= @peeked.length
        @peeked[0...length]
      else
        read_bytes = @in.read(length - @peeked.length)    
        @peeked << read_bytes if read_bytes
        @peeked
      end
    end
  
    def peek_1
      peek(1).unpack("C").first
    end
  
    def peek_2
      peek(2).unpack("n").first
    end
  
    def read_1
      read(1).unpack("C").first
    end
  
    def read_2
      read(2).unpack("n").first
    end
 
    def read_4
      read(4).unpack("N").first
    end
  
    def read_string(length)
      read(length)
    end
  
    def read_atom
      fail("Invalid Type, not an atom") unless read_1 == ATOM
      length = read_2
      if length == 0
        ''
      else
        read_string(length).to_sym
      end
    end
  
    def read_small_int
      fail("Invalid Type, not a small int") unless read_1 == SMALL_INT
      read_1
    end
  
    def read_int
      fail("Invalid Type, not an int") unless read_1 == INT
      value = read_4
      negative = (value >> 31)[0] == 1
      value = (value - (1 << 32)) if negative
      value = Fixnum.induced_from(value)
    end
  
    def read_small_bignum
      fail("Invalid Type, not a small bignum") unless read_1 == SMALL_BIGNUM
      size = read_1
      sign = read_1
      bytes = read_string(size).unpack("C" * size)
      added = bytes.zip((0..bytes.length).to_a).inject(0) do |result, byte_index| 
        byte, index = *byte_index
        value = (byte * (256 ** index))
        sign != 0 ? (result - value) : (result + value) 
      end
      Bignum.induced_from(added)
    end
  
    def read_large_bignum
      fail("Invalid Type, not a large bignum") unless read_1 == LARGE_BIGNUM
      size = read_4
      sign = read_1
      bytes = read_string(size).unpack("C" * size)
      added = bytes.zip((0..bytes.length).to_a).inject(0) do |result, byte_index| 
        byte, index = *byte_index
        value = (byte * (256 ** index))
        sign != 0 ? (result - value) : (result + value) 
      end
      Bignum.induced_from(added)
    end
  
    def read_float
      fail("Invalid Type, not a float") unless read_1 == FLOAT
      string_value = read_string(31)
      result = string_value.to_f
    end
  
    def read_new_reference
      fail("Invalid Type, not a new-style reference") unless read_1 == NEW_REF
      size = read_2
      node = read_atom
      creation = read_1
      id = (0...size).map{|i| read_4 }
      NewReference.new(node, creation, id)
    end
  
    def read_pid
      fail("Invalid Type, not a pid") unless read_1 == PID
      node = read_atom
      id = read_4
      serial = read_4
      creation = read_1
      Terms::Pid.new(node, id, serial, creation)
    end
  
    def read_small_tuple
      fail("Invalid Type, not a small tuple") unless read_1 == SMALL_TUPLE
      arity = read_1
    
      (0...arity).map{|i| read_any_raw }
    end
  
    def read_large_tuple
      fail("Invalid Type, not a small tuple") unless read_1 == LARGE_TUPLE
      arity = read_4
      (0...arity).map{|i| read_any_raw}
    end
  
    def read_nil
      fail("Invalid Type, not a nil list") unless read_1 == NIL
      []
    end
  
    def read_erl_string
      fail("Invalid Type, not an erlang string") unless read_1 == STRING
      length = read_2
      read_string(length).unpack('C' * length)
    end
  
    def read_list
      fail("Invalid Type, not an erlang list") unless read_1 == LIST
      length = read_4
      list = (0...length).map{|i| read_any_raw}
      read_1
      list
    end
  
    def read_bin
      fail("Invalid Type, not an erlang binary") unless read_1 == BIN
      length = read_4
      read_string(length)
    end
  
    def fail(str)
      raise DecodeError, str
    end
    
  end
end
