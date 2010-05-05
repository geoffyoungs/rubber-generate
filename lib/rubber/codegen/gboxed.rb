require 'rubber/codegen/class'

module Rubber

class C_GBoxed < C_Class
  attr_accessor :gparent_class, :flag_nocopy, :c_type_name
  def register(io, already_defined=false)
      io.puts "  #{cname} = G_DEF_CLASS(#{superclass}, #{name.inspect}, #{parent.cname});"
      io.puts "  rbgobj_boxed_not_copy_obj(#{superclass});" if self.flag_nocopy
      
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
  def default_type
	  c_type_name && (c_type_name + ' *') || 'gpointer'
  end
  def pre_func(io, func)
    io.puts "  #{default_type} _self = ((#{default_type})RVAL2BOXED(self, #{superclass}));" if func.text =~ /_self/
    super(io, func)
  end
end

end # Rubber
