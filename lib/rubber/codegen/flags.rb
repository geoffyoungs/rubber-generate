module Rubber

class C_Flags
  define_members :name, :args, :parent
  attr_reader :child_names
  @@declared_base = false
  @@declared_register = false
  def init()
    ($custom_maps[name] ||= {})["VALUE"] = "flags_#{name}_to_ruby((%%))"
    ($custom_maps["VALUE"] ||= {})[name] = "flags_ruby_to_#{name}((%%))"
    @splits = strip_prefixes(args)
    @strip = args.first.length - @splits.first.length
  end
  def code(io)
  end
  def declare(io)
    io.puts "static VALUE #{cname};"
    unless @@declared_base
    	@@declared_base = true
    	io.puts "

static VALUE flagsBaseClass;

typedef struct {
	int value;
	char *name;
	char *fullname;
} FlagsData;

static VALUE make_flags_value(VALUE klass, int value, char *name, char *fullname)
{
	FlagsData *data = NULL;
	
	data = ALLOC(FlagsData);
	data->value = value;
	data->name = name;
	data->fullname = fullname;
	
	return Data_Wrap_Struct(klass, NULL, free, data);
}
static int value_to_int(VALUE value, VALUE klass)
{
	switch (TYPE(value))
	{
	case T_FIXNUM:
	case T_FLOAT:
		return NUM2INT(value);
	break;
	case T_DATA:
		if (rb_obj_is_kind_of(value, flagsBaseClass))
		{
			FlagsData *data = NULL;
			
			if ((klass != Qnil) && (!rb_obj_is_kind_of(value, klass)))
			{
				rb_raise(rb_eTypeError, \"Wrong type of flags  %s (%s required)\", rb_obj_classname(value), rb_class2name(klass));
			}
			
			Data_Get_Struct(value, FlagsData, data);
			return data->value;
		}
	break;
	}
	return 0;
	
}

static VALUE rubber_flags_inspect(VALUE value)
{
	FlagsData *data = NULL;
	volatile VALUE str = rb_str_new(\"#<\", 2);
	char number[16] = \"\"; 
	
	Data_Get_Struct(value, FlagsData, data);
	
	rb_str_cat2(str, rb_obj_classname(value));
	rb_str_cat2(str, \" - \");
	rb_str_cat2(str, data->name);
	rb_str_cat2(str, \"(\");
	sprintf(number, \"%i\", data->value);
	rb_str_cat2(str, number);
	rb_str_cat2(str, \")>\");
	
	return str;
}

static VALUE rubber_flags_to_s(VALUE value)
{
	FlagsData *data = NULL;
	
	Data_Get_Struct(value, FlagsData, data);
	
	return rb_str_new2(data->fullname);
}
static VALUE rubber_flags_name(VALUE value)
{
	FlagsData *data = NULL;
	
	Data_Get_Struct(value, FlagsData, data);
	
	return rb_str_new2(data->name);
}

static VALUE rubber_flags_cmp(VALUE value, VALUE other)
{
	VALUE a,b;
	a = rb_funcall(value, rb_intern(\"to_i\"), 0);
	b = rb_funcall(other, rb_intern(\"to_i\"), 0);
	return rb_num_coerce_cmp(a, b);
}

static VALUE rubber_flags_to_i(VALUE value)
{
	FlagsData *data = NULL;
	
	Data_Get_Struct(value, FlagsData, data);
	
	return INT2FIX(data->value);
}

static VALUE rubber_flags_coerce(VALUE value, VALUE other)
{
	FlagsData *data = NULL;
	
	Data_Get_Struct(value, FlagsData, data);
	
	switch(TYPE(other))
	{
	case T_FIXNUM:
	case T_BIGNUM:
		return INT2FIX(data->value);
	case T_FLOAT:
		return Qnil;
	default:
		return Qnil;
	}
}

"
    end
    args.each do |arg|
      io.puts "static VALUE #{default_cname}_#{arg} = Qnil;"
    end    
    io.puts "typedef int #{name};
#ifdef __GNUC__
// No point in declaring these unless we're using GCC
// They're ahead of any code that uses them anyway.
static VALUE flags_#{name}_to_ruby(int value)
__attribute__ ((unused))
;
static int flags_ruby_to_#{name}(VALUE val)
__attribute__ ((unused))
;
#endif

"
    io.puts "static VALUE flags_#{name}_to_ruby(int value) { switch(value) {"
    args.each do |arg|
      io.puts "    case #{arg}: return #{default_cname}_#{arg};"
    end    
    io.puts "}; return Qnil; }"
    io.puts "static int flags_ruby_to_#{name}(VALUE val) { return value_to_int(val, #{cname}); }"
  end
  include RegisterChildren
  def default_cname
    "flags"+name
  end
  def doc_rd(io)
    depth = (fullname.gsub(/[^:]/,'').size >> 1)
    io.puts "=#{'=' * depth} flags #{fullname}"
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
    unless @@declared_register
    	@@declared_register = true
      io.puts "  flagsBaseClass = rb_define_class(\"Flags\", rb_cObject);"
      io.puts '    rb_define_method(flagsBaseClass, "inspect", rubber_flags_inspect, 0);'
      io.puts '    rb_define_method(flagsBaseClass, "to_i", rubber_flags_to_i, 0);'
      io.puts '    rb_define_method(flagsBaseClass, "coerce", rubber_flags_coerce, 1);'
      io.puts '    rb_define_method(flagsBaseClass, "to_s", rubber_flags_to_s, 0);'
      io.puts '    rb_define_method(flagsBaseClass, "to_str", rubber_flags_to_s, 0);'
      io.puts '    rb_define_method(flagsBaseClass, "fullname", rubber_flags_to_s, 0);'
      io.puts '    rb_define_method(flagsBaseClass, "name", rubber_flags_name, 0);'
      io.puts '    rb_define_method(flagsBaseClass, "<=>", rubber_flags_cmp, 0);'
      io.puts '    '
    end
    if parent
      io.puts "  #{cname} = rb_define_class_under(#{parent.cname}, #{name.inspect}, flagsBaseClass);"
    else
      io.puts "  #{cname} = rb_define_class(#{name.inspect}, flagsBaseClass);"
    end
    
    args.each do |arg|
      uniq = arg[@strip..-1]
      io.puts "    #{default_cname}_#{arg} = make_flags_value(#{cname}, #{arg}, #{uniq.downcase.gsub(/_/,'-').inspect}, #{arg.inspect});"
      io.puts "    rb_obj_freeze(#{default_cname}_#{arg});"
      io.puts "    rb_define_const(#{cname}, #{uniq.upcase.inspect}, #{default_cname}_#{arg});"
    end
  end
end

end # Rubber
