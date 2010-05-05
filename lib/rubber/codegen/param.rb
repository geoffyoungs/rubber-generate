module Rubber

class C_Param
  define_members :name, :ctype, :default, :block, :rest, :rtype
  RUBY_NATIVE_TYPES = %w|T_NIL T_OBJECT T_CLASS T_MODULE T_FLOAT T_STRING T_REGEXP T_ARRAY T_FIXNUM T_HASH T_STRUCT T_BIGNUM T_FILE T_TRUE T_FALSE T_DATA T_SYMBOL|
  RUBY_NATIVE_NAMES = %w|Nil Object Class Module Float String Regexp Array Fixnum Hash Struct Bignum File True False Data Symbol|

  def initialize(str)
    r = StringScanner.new(str)
    @ctype = r.scan(/[a-z_A-Z0-9|]+\s[*]*/) || 'VALUE'
    @ctype.squeeze!(' ') if @ctype
    @ctype.strip! if @ctype
    if RUBY_NATIVE_TYPES.include?(@ctype)
      @rtype = @ctype
      @ctype = 'VALUE'
    elsif (types = @ctype.split(/\|/)).size > 1
      types.each { |i| i.strip! }
      if RUBY_NATIVE_TYPES.include?(types.first)
        @ctype = "VALUE"
        @rtype = types
      end
    end
    r.skip(/\s*/)
    @rest = (r.skip(/\*/) and true)
    @block = (r.skip(/\&/) and true)
    @name = r.scan(/[A-Za-z0-9_]+/)
    r.skip(/\s*/)
    if r.scan(/=(.*)/)
      @default= r[1].strip
    end
  end
  #include RegisterChildren
  def cname()
    if auto_convert?
      "__v_#{name}"
    else
      name
    end
  end
  def auto_convert?
    ctype and ctype != "VALUE"
  end
  def init_value()
    if @block and not @default
      "rb_block_proc()"
    else
      "Qnil"
    end
  end
  def check_type(io)
    case @rtype
    when String
      io.puts "  Check_Type(#{cname}, #{@rtype});"
    when Array
      io.puts "  if (! (" + @rtype.collect { |type|  "(TYPE(#{cname}) == #{type})" }.join(' || ') + ") )"
      io.puts "    rb_raise(rb_eArgError, \"#{name} argument must be one of #{@rtype.collect {|i| RUBY_NATIVE_NAMES[RUBY_NATIVE_TYPES.index(i)]}.join(', ') }\");"
    end
  end
  def declare(io,fn)
    if auto_convert?
      io.puts "  VALUE #{cname} = #{init_value};" if fn.multi
      io.puts "  #{ctype} #{name}; #{ctype} __orig_#{name};"
    else
      io.puts "  VALUE #{cname} = #{init_value};" if fn.multi
    end
  end
  def to_str()
    "#{ctype} #{name} #{default ? ' = ' + default : ''}"
  end
  NICE_CNAMES= {'char*'=> 'String', 'long'=>'Integer', 'int'=>'Integer', 'uint'=>'Unsigned Integer', 'ulong'=>'Unsigned Integer', 'bool'=>'Boolean'}
  def ruby_def()
    if @rtype.kind_of?(String)
      type = RUBY_NATIVE_NAMES[RUBY_NATIVE_TYPES.index(rtype)] + ' '
    elsif @rtype.kind_of?(Array)
      types = @rtype.dup
      types.delete('T_NIL') # Don't mention nil option
      type = types.collect { |rtype| RUBY_NATIVE_NAMES[RUBY_NATIVE_TYPES.index(rtype)] }.join(' or ') + ' '
    elsif ctype and ctype != 'VALUE'
      if NICE_CNAMES.has_key?(ctype)
        type = NICE_CNAMES[ctype]
      else
        type = ctype
      end
      type += ' '
    else
      type = ''
    end
    "#{type}#{name}"
  end
end

end # Rubber
