module Rubber

class C_GCRefPool
  define_members :name
  def code(io)
    io.puts "static void _#{cname}_add(VALUE val)
    {
      if (#{cname} == Qnil)
      {
        #{cname} = rb_ary_new3(1, val);
      }
      else
      {
        rb_ary_push(#{cname}, val);
      }
    }
    
    static void _#{cname}_del(VALUE val)
    {
      if (#{cname} == Qnil)
      {
        rb_warn(\"Trying to remove object from empty GC queue #{name}\");
        return;
      }
      rb_ary_delete(#{cname}, val);
      // If nothing is referenced, don't keep an empty array in the pool...
      if (RARRAY(#{cname})->len == 0)
        #{cname} = Qnil;
    }
    "
  end
  def declare(io)
    io.puts "static VALUE #{cname} = Qnil;"
    io.puts "static void _#{cname}_add(VALUE val);"
    io.puts "static void _#{cname}_del(VALUE val);"
    io.puts "#define #{name.upcase}_ADD(val) _#{cname}_add(val)"
    io.puts "#define #{name.upcase}_DEL(val) _#{cname}_del(val)"
  end
  include RegisterChildren
  def default_cname
    "_gcpool_"+name
  end
  def doc_rd(io)
    # No doc 
  end
  def fullname()
  end
  def register(io, already_defined=false)
    io.puts "rb_gc_register_address(&#{cname});"
  end
end

end # Rubber
