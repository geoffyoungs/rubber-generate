module Rubber

class C_Module
  define_members :name, :classes, :methods, :functions, :constants, :includes, :parent
  attr_accessor :doc, :child_names
  def contents()
    (functions + methods + classes)
  end
  def code(io)
    contents .each { |f| f.code(io) }
  end
  def declare(io)
    io.puts "static VALUE #{cname};" unless external?
    contents .each { |f| f.declare(io) }
  end
  include RegisterChildren
  def default_cname
    "m"+name
  end
  def doc_rd(io)
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} module #{fullname}"
    io.puts @doc if @doc
    contents .each { |f| f.doc_rd(io) }
  end
  def get_root(); is_root? ? self : parent.get_root; end
  def is_root?()
    not parent.respond_to?(:fullname)
  end
  def fullname()
    if is_root?
      name
    else
      #p parent
      "#{parent.fullname}::#{name}"
    end
  end
  def external? # ie. *defined* externally...
    cname == 'mGtk' || cname == 'mGdk' || cname == "mGLib"
  end
  def add_alias(from, to)
  	(@aliases ||= []) << [from, to]
  end
  def register_aliases(io)
    if @aliases
      @aliases.each do |from,to|
        io.puts "  rb_define_alias(#{cname},#{from.inspect},#{to.inspect});"
      end
    end
  end
  def register(io, already_defined=false)
    unless external?
      if parent and not parent.kind_of?(C_RootModule)
        io.puts "  #{cname} = rb_define_module_under(#{parent.cname}, #{name.inspect});"
      else
        io.puts "  #{cname} = rb_define_module(#{name.inspect});"
      end
    end
    register_children(io)
  end
end

end # Rubber
