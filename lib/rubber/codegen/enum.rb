module Rubber

class C_Enum
  define_members :name, :args, :parent
  attr_reader :child_names
  @@declared_base = false
  @@declared_register = false
  def init()
    ($custom_maps[name] ||= {})["VALUE"] = "enum_#{name}_to_ruby((%%))"
    ($custom_maps["VALUE"] ||= {})[name] = "enum_ruby_to_#{name}((%%))"
    STDERR.puts "Auto-adding custom map for #{name}"
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

static VALUE enumBaseClass;

typedef struct {
	int value;
	char *name;
	char *fullname;
} EnumData;

static VALUE make_enum_value(VALUE klass, int value, char *name, char *fullname)
{
	EnumData *data = NULL;
	
	data = ALLOC(EnumData);
	data->value = value;
	data->name = name;
	data->fullname = fullname;
	
	return Data_Wrap_Struct(klass, NULL, free, data);
}
static int enum_value_to_int(VALUE value, VALUE klass)
{
	switch (TYPE(value))
	{
	case T_FIXNUM:
	case T_FLOAT:
		return NUM2INT(value);
	break;
	case T_DATA:
		if (rb_obj_is_kind_of(value, enumBaseClass))
		{
			EnumData *data = NULL;
			
			if ((klass != Qnil) && (!rb_obj_is_kind_of(value, klass)))
			{
				rb_raise(rb_eTypeError, \"Wrong type of enum  %s (%s required)\", rb_obj_classname(value), rb_class2name(klass));
			}
			
			Data_Get_Struct(value, EnumData, data);
			return data->value;
		}
	break;
	}
	return 0;
	
}

static VALUE rubber_enum_inspect(VALUE value)
{
	EnumData *data = NULL;
	volatile VALUE str = rb_str_new(\"#<\", 2);
	char number[16] = \"\"; 
	
	Data_Get_Struct(value, EnumData, data);
	
	rb_str_cat2(str, rb_obj_classname(value));
	rb_str_cat2(str, \" - \");
	rb_str_cat2(str, data->name);
	rb_str_cat2(str, \"(\");
	sprintf(number, \"%i\", data->value);
	rb_str_cat2(str, number);
	rb_str_cat2(str, \")>\");
	
	return str;
}

static VALUE rubber_enum_to_s(VALUE value)
{
	EnumData *data = NULL;
	
	Data_Get_Struct(value, EnumData, data);
	
	return rb_str_new2(data->fullname);
}
static VALUE rubber_enum_name(VALUE value)
{
	EnumData *data = NULL;
	
	Data_Get_Struct(value, EnumData, data);
	
	return rb_str_new2(data->name);
}

static VALUE rubber_enum_cmp(VALUE value, VALUE other)
{
	VALUE a,b;
	a = rb_funcall(value, rb_intern(\"to_i\"), 0);
	b = rb_funcall(other, rb_intern(\"to_i\"), 0);
	return rb_num_coerce_cmp(a, b);
}

static VALUE rubber_enum_to_i(VALUE value)
{
	EnumData *data = NULL;
	
	Data_Get_Struct(value, EnumData, data);
	
	return INT2FIX(data->value);
}

static VALUE rubber_enum_coerce(VALUE value, VALUE other)
{
	EnumData *data = NULL;
	
	Data_Get_Struct(value, EnumData, data);
	
	switch(TYPE(other))
	{
	case T_FIXNUM:
	case T_BIGNUM:
		return INT2FIX(data->value);
	case T_FLOAT:
		return rb_float_new(data->value);
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
static VALUE enum_#{name}_to_ruby(int value)
__attribute__ ((unused))
;
static int enum_ruby_to_#{name}(VALUE val)
__attribute__ ((unused))
;
#endif

"
    io.puts "static VALUE enum_#{name}_to_ruby(int value) { switch(value) {"
    args.each do |arg|
      io.puts "    case #{arg}: return #{default_cname}_#{arg};"
    end    
    io.puts "}; return Qnil; }"
    io.puts "static int enum_ruby_to_#{name}(VALUE val) { return enum_value_to_int(val, #{cname}); }"
  end
  include RegisterChildren
  def default_cname
    "enum"+name
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
    unless @@declared_register
    	@@declared_register = true
      io.puts "  enumBaseClass = rb_define_class(\"Enum\", rb_cObject);"
      io.puts '    rb_define_method(enumBaseClass, "inspect", rubber_enum_inspect, 0);'
      io.puts '    rb_define_method(enumBaseClass, "to_i", rubber_enum_to_i, 0);'
      io.puts '    rb_define_method(enumBaseClass, "coerce", rubber_enum_coerce, 1);'
      io.puts '    rb_define_method(enumBaseClass, "to_s", rubber_enum_to_s, 0);'
      io.puts '    rb_define_method(enumBaseClass, "to_str", rubber_enum_to_s, 0);'
      io.puts '    rb_define_method(enumBaseClass, "fullname", rubber_enum_to_s, 0);'
      io.puts '    rb_define_method(enumBaseClass, "name", rubber_enum_name, 0);'
      io.puts '    rb_define_method(enumBaseClass, "<=>", rubber_enum_cmp, 0);'
      io.puts '    '
    end
    if parent
      io.puts "  #{cname} = rb_define_class_under(#{parent.cname}, #{name.inspect}, enumBaseClass);"
    else
      io.puts "  #{cname} = rb_define_class(#{name.inspect}, enumBaseClass);"
    end
    
    args.each do |arg|
      uniq = arg[@strip..-1]
      uniq.sub!(/\A[^a-zA-Z]/,'')
      io.puts "    #{default_cname}_#{arg} = make_enum_value(#{cname}, #{arg}, #{uniq.downcase.gsub(/_/,'-').inspect}, #{arg.inspect});"
      io.puts "    rb_obj_freeze(#{default_cname}_#{arg});"
      io.puts "    rb_define_const(#{cname}, #{uniq.upcase.inspect}, #{default_cname}_#{arg});"
    end
  end
end

end # Rubber
