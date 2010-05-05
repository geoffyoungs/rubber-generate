require 'rubber/codegen/class'

module Rubber

class C_GObject < C_Class
  attr_accessor :gparent_class, :c_type_name
  def init()
	  @c_type_name ||= 'GObject' # Default
  end
#	def c_type
#		fullname.sub(/::/,'')+' *'
#	end
  def register(io, already_defined=false)
      if parent.child_names && parent.child_names[name]
      	io.puts "  c#{name} = #{cname};"
      else
      	io.puts "  #{cname} = G_DEF_CLASS(#{superclass}, #{name.inspect}, #{parent.cname});"
      end
      io.puts @signal_marshals if defined?(@signal_marshals)
      register_children(io)
  end
  def doc_rd(io)
    id = fullname()
    id += " < #{gparent_class} " if gparent_class
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} class #{id}"
    io.puts @doc if @doc
    contents.each { |f| f.doc_rd(io) }
  end
  def feature_signal_marshal(signal,func_name)
  	@signal_marshals ||= ""
	@signal_marshals << "  G_DEF_SIGNAL_FUNC(#{cname}, #{signal.inspect}, #{func_name});\n"
  end
  def pre_func(io, func)
	if func.text =~ /_self/
	    io.puts "  #{@c_type_name} *_self = ((#{@c_type_name}*)RVAL2GOBJ(self));"
	end
    super(io, func)
  end
end

end # Rubber
