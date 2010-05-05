module Rubber

class C_String
  define_members :name, :string, :parent
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
      io.puts "    rb_define_const(#{parent.cname}, #{name.inspect}, rb_str_new2(#{string}));"
    else
      raise "No parent for string constant #{name}"
    end
  end
end

end # Rubber
