require 'rubber/codegen/class'

module Rubber

class C_Struct < C_Class
  define_members :name, :args, :parent
  attr_reader :child_names
  def init
  	@functions = []
  	@classes = []
  	@methods = []
  end
  def declare(io)
    io.puts "static VALUE #{cname};"
  end
  include RegisterChildren
  def default_cname
    "struct"+name
  end
  def doc_rd(io)
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} enum #{fullname}"
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
  def same_prefix(arr)
    for i in arr
      return false if arr.first.first != i.first
    end
    return true
  end
  def strip_prefixes(arr)
    splits = arr.collect { |i| i.strip.split(/_/) }
    while (same_prefix(splits))
      splits.each { |i| i.shift }
    end
    splits.collect!{|i| i.join('_') }
    splits
  end
  def get_root(); is_root? ? self : parent.get_root; end; 
  def is_root?()
    not parent.respond_to?(:fullname)
  end
  def register(io, already_defined=false)
    io.puts "  #{cname} = rb_struct_define(#{name.inspect}, #{args.map{|m|m[0]==?" && m || m.inspect}.join(', ')}, NULL);"
    if parent
      io.puts "    rb_define_const(#{parent.cname}, #{name.inspect}, #{cname});"
    else
      #io.puts "    rb_define_const(#{parent.cname}, #{name.inspect}, #{cname});"
    end
    register_children(io)
  end
end

end # Rubber
