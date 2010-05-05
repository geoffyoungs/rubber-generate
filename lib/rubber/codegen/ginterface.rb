require 'rubber/codegen/class'

module Rubber

class C_GInterface < C_Class
  attr_accessor :gparent_class
  def register(io, already_defined=false)
      io.puts "  #{cname} = G_DEF_INTERFACE(#{superclass}, #{name.inspect}, #{parent.cname});"
      register_children(io)
  end
  def doc_rd(io)
    id = fullname()
    id += " < #{gparent_class} " if gparent_class
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} interface #{id}"
    io.puts @doc if @doc
    contents.each { |f| f.doc_rd(io) }
  end
  def pre_func(io, func)
    io.puts "  GObject *_self = RVAL2GOBJ(self);" if func.text =~ /_self/
    super(io, func)
  end
end

end # Rubber
