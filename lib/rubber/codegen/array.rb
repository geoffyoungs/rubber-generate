module Rubber

class C_Array
  define_members :name, :values, :parent
  def code(io)
  end
  def declare(io)
    #io.puts "static VALUE #{cname};"
  end
  include RegisterChildren
  def default_cname
    #"enum"+name
  end
  def doc_rd(io)
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} #{fullname}"
  end
  def get_root(); is_root? ? self : parent.get_root; end; def is_root?()
    not parent.respond_to?(:fullname)
  end
  def fullname()
    if parent and parent.respond_to?(:fullname)
      "#{parent.fullname}::#{name}"
    else
      name
    end
  end
  def get_root(); is_root? ? self : parent.get_root; end; 
  def is_root?()
    not parent.respond_to?(:fullname)
  end
  def register(io, already_defined=false)
    if parent
		args = "#{@values.size}"
		@values.each_with_index do |hash, index|
			args << ", "
			case hash.keys[0]
			when :int
				args << "INT2NUM(#{hash.values[0]})"
			when :bool
				args << "((#{hash.values[0]}) ? Qtrue : Qfalse)"
			when :float
				args << "FLOAT2NUM(#{hash.values[0]})"
			when :string
				args << "rb_str_new2(#{hash.values[0]})"
			when :nil
				args << "Qnil"
			else
				raise "Unknown key type for static array - #{hash.keys[0]}"
			end
		end
		io.puts "    rb_define_const(#{parent.cname}, #{name.inspect}, rb_ary_new3(#{args}));"
    else
      raise "No parent for string constant #{name}"
    end
  end
end

end # Rubber
