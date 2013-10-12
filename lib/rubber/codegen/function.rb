module Rubber

class C_Function
  define_members(:name, :args, :text, :parent, {:autofree=>[]}, {:returntype=>'VALUE'}, :doc=>'')
  attr_accessor :source_line, :source_file
  attr_reader :multi, :block, :rest, :singleton
  def check()
    return if @checked
    @block = @rest = @multi = false
    @singleton = true if name.include?('.')
    @arghash = {}
    @min_args = 0
    @opt_args = 0
    args.each { |arg|
      @arghash[arg.name] = arg
      raise "Too many block parameters for #{parent.name}.#{name.gsub(/^self./,'')}" if @block and arg.block 
      raise "Too many rest parameters for #{parent.name}.#{name}" if @rest and arg.rest
      @multi = true if arg.default or arg.rest
      if @multi
        @opt_args += 1 unless arg.block or arg.rest
      else
        @min_args += 1 unless arg.block
      end
      @block = arg if arg.block
      @rest = arg if arg.rest
    }
    @scan_string = "#{@min_args}#{@opt_args}#{@rest ? "*" : ""}#{@block ? "&" : ""}"
    @vars ||= {}
    @checked = true
  end
  def rname()
    name.split(/\./).last
  end
  #include RegisterChildren
  def cname()
   @cname ||= parent.name + ( @singleton ? '_CLASS' :'') + '_' + rname.gsub(/[?]/, '_query'). gsub(/[!]/, '_pling'). gsub(/[=]/, '_equals'). gsub(/[\[\]]/, '_brace')
  end
  def fullname()
    check()
    str = parent.fullname.dup
    if name == 'initialize'
        str << ".new"
    else
        str << ( @singleton ? (/^[a-zA-Z]/.match(rname) ? ".#{rname}" : rname) : "##{rname}")
    end
    str
  end
  def doc_rd(io)
    io << "--- #{fullname}"
    io << "(#{args.collect { |i| i.ruby_def }.join(', ')})\n" unless (fullname =~ /[!?]\z/ || !@singleton) and args.empty?
    io.puts doc
    io << "\n"
  end
  def prototype(io)
    io.puts "static VALUE"
    io.write "#{cname}("
    if @multi
      io.write "int __p_argc, VALUE *__p_argv, VALUE self"
    else
      io.write "VALUE self OPTIONAL_ATTR "
      io.write(args.reject {|i| i.block }.collect { |i| ', VALUE ' + i.cname + " OPTIONAL_ATTR" }.join(''))
      #io.write ", " if args.size > 1 or (args.size > 0 and not @block)
    end
    io.write ")"
  end
  def declare(io)
    check()
    prototype(io)
    io.puts ";"
  end
  def guess(name)
    if name == 'self'
      'VALUE'
    elsif name == '_self' and parent.kind_of?(C_GObject)
      'GObject*'
    elsif @vars[name]
      @vars[name]
    else
      if name =~ /^([A-Za-z0-9_]+)\[.*$/
        if @vars[$1]
          @vars[$1]
        else
          VALUE;
        end
      else
        'VALUE'
      end
    end
  end
  CAST_SAFER= /\<\{([a-z0-9A-Z* ]+)(>[a-z0-9A-Z* ]+)?:([^{};:]+)\}\>/
  CAST= /\<([^:;{}]+):([a-z0-9A-Z* ]+)\>/
  def code(io)
    require 'stringio'
    check()
    prototype(io)
    io.puts ""
    io.puts "{"
    oio = io
    io = StringIO.new()
    args.each { |arg| 
      arg.declare(io,self) unless not @multi and not arg.auto_convert? and not arg.block
    }
    parent.pre_func(io, self) if parent.respond_to?(:pre_func)
    if @multi 
      io.puts ""
      io.puts "  /* Scan arguments */"
      io.puts("  rb_scan_args(__p_argc, __p_argv, #{@scan_string.inspect},#{args.collect {|i| "&"+i.cname }.join(', ') });")
      io.puts ""
      
      io.puts "  /* Set defaults */"
      args.each_index { |i| 
        arg = args[i]
        if arg.auto_convert?
          io.write("  if (__p_argc > #{i})\n  ") if arg.default
          io.puts("  __orig_#{arg.name} = #{arg.name} = #{Rubber::explicit_cast(arg.cname, 'VALUE', arg.ctype)};")
          io.puts("  else\n    #{arg.name} = #{arg.default};") if arg.default
        else
          io.puts("  if (__p_argc <= #{i})\n    #{arg.name} = #{arg.default};") if arg.default and not arg.block
          io.puts("  else") if arg.default and arg.rtype
          arg.check_type(io) if arg.rtype
        end
        io.puts "" if arg.default or arg.auto_convert?
      }
      #io.puts("  switch (argc) {")
      #for i in @min_args .. @min_args + @opt_args
      #  io.puts "    case #{i}:"
      #end
      #io.puts("  }")
    else
      args.each { |arg|
        if arg.auto_convert?
          io.puts("  __orig_#{arg.name} = #{arg.name} = #{Rubber::explicit_cast(arg.cname, 'VALUE', arg.ctype)};")
        elsif arg.block
          io.puts("  VALUE #{arg.name} OPTIONAL_ATTR = #{arg.init_value()};")
        else
           arg.check_type(io) if arg.rtype
        end
     }
    end

    io.puts ""
	io.puts "#line #{source_line} #{source_file.inspect}" if source_line
    setupvars = io.string
    io = oio
    
    returned = false
    oio =io
    io = StringIO.new()
    sc = StringScanner.new(text.strip)
    io.write "  " # Initial indent
     until sc.empty?
     if txt = sc.scan(CAST_SAFER)
        from_type, to_type, cast = sc[1], sc[2], sc[3]
        arg = @arghash[cast]
	to_type = to_type[1..-1] unless to_type.nil? or to_type.empty?
	to_type = (!(to_type.nil? or to_type.empty?) && to_type || (arg && arg.ctype || guess(cast)))
        io.write(Rubber.explicit_cast(cast, from_type, to_type))
     elsif txt = sc.scan(CAST)
		warn("<TYPE:VALUE> is deprecated - please use <{FROM_TYPE>TO_TYPE:VALUE}> instead.")
        name, cast = sc[1], sc[2]
        arg = @arghash[name]
        io.write(Rubber::explicit_cast(name, arg && arg.ctype || guess(name), cast))
      elsif txt = sc.scan(/['"]/) #' Skip quoted string
        txt += sc.scan_until(/(^|[^\\])#{txt}/) # Skip until unescaped quote
        io.write(txt)
      elsif c = sc.scan(/;/)
        io.write ";\n "
      elsif c = sc.scan(/return\s+/)
        val = sc.scan_until(/;/)
        val.strip! if val
        if val and val.size > 1
          val.chop! # Trim last char
          io.write "do { __p_retval = "
          # Scan returned bit for casts
          retval = ""
          mini_scanner = StringScanner.new(val)
          until mini_scanner.eos?
            if txt = mini_scanner.scan(CAST_SAFER)
              from_type, to_type, cast = mini_scanner[1], mini_scanner[2], mini_scanner[3]
       	      arg = @arghash[cast]
	      to_type = to_type[1..-1] unless to_type.nil? or to_type.empty?
	      to_type = (!(to_type.nil? or to_type.empty?) && to_type || (arg && arg.ctype || guess(cast)))
              retval << (Rubber::explicit_cast(cast, from_type, to_type))
            elsif txt = mini_scanner.scan(CAST)
	      warn("<TYPE:VALUE> is deprecated - please use <{TYPE>TO:VALUE}> instead.")
              name, cast = mini_scanner[1], mini_scanner[2]
              arg = @arghash[name]
              retval << (Rubber::explicit_cast(name, arg && arg.ctype || guess(name), cast))
            else
              retval << (mini_scanner.get_byte)
            end
          end
          unless Rubber.native_type?(returntype)
            io << Rubber.explicit_cast(retval, returntype, 'VALUE')
          else
            io << retval
          end
          #end of internal scan
          io.write "; goto out; } while(0);"
          returned = true
        else
          parent.post_func(io, self) if parent.respond_to?(:post_func)
          io.write(";")
        end
      elsif c = sc.scan(/([a-z0-9A-Z_]+[ *]+)([a-zA-Z0-9]+)\s*([\[\]0-9]*)\s*([;=])/)
        io.write "#{[sc[1], sc[2], sc[3], sc[4]].join(' ')}\n"
        @vars ||= {}
        base = sc[1].split(/\s/).first
        p = 0
        (sc[1]+sc[3]).each_byte { |i| p += 1 if i == ?[  or i == ?* }
        @vars[sc[2]] = base.strip + ( p > 0  && (' ' + ('*' * p)) || '' )
      elsif c = sc.get_byte
        io.write(c)
      end
    end
   
    code = io.string
    io = oio
    
    
    io.puts "  VALUE __p_retval OPTIONAL_ATTR = #{default()};" if returned
    io.puts setupvars
    io.puts "\n  do {" if @vars and not @vars.empty?
    io.puts code
    io.puts "\n  } while(0);\n\n" if @vars and not @vars.empty?
    io.puts "out:" if returned
    parent.post_func(io, self) if parent.respond_to?(:post_func)
    
    args.each { |arg|
        if arg.auto_convert? && $custom_frees[arg.ctype.gsub(/ /,'')]
          io.puts($custom_frees[arg.ctype].gsub(/%%/,"__orig_#{arg.name}")+";")
	end
     }

    if returned
      io.puts "  return __p_retval;"
    else
      io.puts "  return #{default()};"
    end
    io.puts "}"
    io.puts ""
  end
  def default
      if rname =~ /=\z/ and args.size == 1
        args.first.cname
      elsif rname =~ /\Aset_/
        "self"
      else
        "Qnil"
      end
  end
  def arity()
    check()
    return -1 if @multi
    num = args.size
    num -= 1 if @block
    num
  end
  def alloc_func?
    name.split(/\./,2).last == '__alloc__'
  end
  def register(io, already_defined=false)
    if alloc_func?
      io.puts " rb_define_alloc_func(#{parent.cname}, #{cname});"
    else
      io.puts "  rb_define_#{@singleton ? "singleton_" : ""}method(#{parent.cname}, #{rname.inspect}, #{cname}, #{arity});"
    end
  end
end

end # Rubber
