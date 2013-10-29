require 'rubber/codegen/module'

module Rubber

class C_Class < C_Module
  define_members :name, :superclass, :methods, :functions, :constants, :ctype, {:classes => []}, :includes, :parent
  attr_accessor :pre_func, :post_func, :doc, :pre_only, :pre_except, :post_only, :post_except
  attr_reader :child_names

  def fullname()
    if parent and parent.respond_to?(:fullname)
      "#{parent.fullname}::#{name}"
    else
      name
    end
  end
  def doc_rd(io)
    id = fullname()
    id += " < #{superclass}" if superclass
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} class #{id}"
    io.puts @doc if @doc
    contents.each { |f| f.doc_rd(io) }
  end
  def get_root(); is_root? ? self : parent.get_root; end
  def is_root?()
    not parent.respond_to?(:fullname)
  end
  def code(io)
    contents .each { |f| f.code(io) }
  end
  def declare(io)
    io.puts "static VALUE #{cname};";
    contents .each { |f| f.declare(io) }
  end
  def register(io, already_defined=false)
    if parent.child_names && parent.child_names[name]
      	io.puts "  c#{name} = #{cname};"
    else
	    if parent and parent.cname
	      io.puts "  #{cname} = rb_define_class_under(#{parent.cname}, #{name.inspect}, #{Rubber.find_class(superclass) || 'rb_cObject'});"
	    else
	      io.puts "  #{cname} = rb_define_class(#{name.inspect}, #{Rubber.find_class(superclass) || 'rb_cObject'});"
	    end
    end
    register_children(io)
  end
  include RegisterChildren
  def default_cname
    "c#{name}"
  end
  def check_wrap_ok(io, fn, where)
    case where
    when :pre
	  code   = @pre_func
	  only   = @pre_only
	  except = @pre_except
	when :post
	  code   = @post_func
	  only   = @post_only
	  except = @post_except
	end
	if code && ! fn.singleton
		return if only && ! only.empty? && ! only.include?(fn.name)
		return if except && except.include?(fn.name)
		io.puts code
	end
  end
  def pre_func(io, func)
    #io.puts @pre_func unless @pre_func.nil? or func.singleton
	check_wrap_ok(io, func, :pre)
  end
  def post_func(io, func)
    #io.puts @post_func unless @post_func.nil? or func.singleton
	check_wrap_ok(io, func, :post)
  end
end

end # Rubber
