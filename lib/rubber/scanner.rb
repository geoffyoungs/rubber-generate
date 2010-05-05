require 'rubber/struct'
module Rubber
class ScanState
  define_members(:in_code, :in_class, :in_func, :braces)
end

class Options
	attr_accessor :gtk, :glib, :gnu
	alias :gtk? :gtk
	alias :glib? :glib
	def []=(name,val)
		instance_variable_set("@"+name,val)
	end
	def [](name)
		instance_variable_get("@"+name)
	end
end

class CRScanner
attr_reader :file, :functions, :nested_functions, :classes, :calls, :allocs, :stack, :ext, :pkgs, :incs, :doc, :raw, :libs, :defs, :pre_init_code, :post_init_code, :inc_dirs, :lib_dirs
attr_reader :options
def initialize(file)
  @file = file
  @ext = File::basename(file).gsub(/\..*$/, '')
  @nested_functions = {}
  @functions = {}
  @modules = {}
  @classes = {}
  @calls = []
  @allocs = []
  @options = Options.new
  # Default settings
  @options.glib= true
  @options.gtk= true
  @options.gnu= false
end
def scan_args()
  args = []
  return args unless @str.peep(1) == '('
  brackets = 1
  arg = ''
  @str.get_byte # Get first bracket
  until @str.peep(1) == ')' and brackets == 1
    brackets += 1 if @str.peep(1) == '('
    brackets -= 1 if @str.peep(1) == ')'
    if brackets == 1 and @str.peep(1) == ','
      @str.pos = @str.pos + 1
      arg.strip!
      args.push arg unless arg.empty?
      arg = ''
    else
      arg += @str.get_byte
    end
  end
  @str.get_byte # Get last bracket
  arg.strip!
  args.push arg unless arg.empty?
  args
end
def stack()
  #p @stack
  @stack
end
attr_accessor :state
def scan(fp)
    _scan(fp)
  rescue Exception
    off,ind = 0,0
    for line in @lines
      off += line.size
      break if off > @str.pos
      ind += 1
    end
    p @state, @str, ind
    raise
end
def _scan(fp)
  @lines = IO.readlines(@file)
  @str = StringScanner.new(@lines.join)
  tokens = []
  @state = ScanState.new(0,0,false,0)
  @stack = [C_RootModule.new]
  func = nil
  until @str.empty?
    ######## Doc
    if @str.skip(/=begin([ \t][^\n]*)?\n/) # skip =begin/=end blocks
      lines = @str.scan_until(/\n=end([ \t].*)?/).split("\n")
      lines.pop
      if state.in_func
        (func.doc ||= "") << lines.join("\n")
      elsif @class and not @class.kind_of?(C_RootModule)
        (@class.doc ||= "") << lines.join("\n")
      else
        (@doc ||= "") << lines.join("\n")
      end
      
    ######## Config 
    
    elsif @str.skip(/%\{/) # Scan raw
      raw = @str.scan_until(/%\}/) 
      raw[-2..-1] = ""
      (@raw ||= "") << raw
    elsif @str.skip(/%pre_init\{/) # Scan raw
      raw = @str.scan_until(/%\}/) 
      raw[-2..-1] = ""
      (@pre_init_code ||= "") << raw
    elsif @str.skip(/%post_init\{/) # Scan raw
      raw = @str.scan_until(/%\}/) 
      raw[-2..-1] = ""
      (@post_init_code ||= "") << raw
    elsif @str.skip(/\s+/) # skip
      func.text += " " if state.in_func
    elsif @str.skip(/%name */) # Extension name
      @ext = @str.scan(/[a-zA-Z0-9]+/)
    elsif @str.skip(/%pkg-config\s*([-a-z.0-9+]+)/) # pkg-config library
      @pkgs ||= []
      @pkgs << @str[1]
    elsif @str.skip(/%include_dir\s+(.+)\n/) # Include dirs
      @inc_dirs ||= []
      @inc_dirs << @str[1].strip
    elsif @str.skip(/%lib_dir\s+(.+)\n/) # Library dir
      @lib_dirs ||= []
      @lib_dirs << @str[1].strip
    elsif @str.skip(/%include\s+(.+)\n/) # Include file
      @incs ||= []
      @incs << @str[1].strip
    elsif @str.skip(/%option +([a-z]+)=(yes|no)\n/) # Option
      case @str[1]
      when 'glib','gtk','gnu'
      	@options[@str[1]] = (@str[2] == 'yes')
      else
        raise "Unknown option #{@str[1]}"
      end
    elsif @str.skip(/%lib\s+(.+)\n/) # Skip single-line comment
      @libs ||= []
      @libs << @str[1].strip
    elsif @str.skip(/%define\s+(.+)\n/) # Skip single-line comment
      @defs ||= []
      @defs << @str[1].strip
    elsif @str.skip(/%equiv[a-z]*\s+([^=\n]+)=([^=\n]+)\n/) # Skip single-line comment
      $equivalents[@str[1].gsub(/ /,'').strip] = @str[2].gsub(/ /,'').strip
    elsif @str.skip(/%map\s+([^->]+?)\>([^:]+):([^@\n]+) *@? *(.*)\n/) # Skip single-line comment
      from, to, code = *[@str[1], @str[2], @str[3]].collect { |i| i.strip }
      free_code = @str[4]
      from.gsub!(/ /,'')
      to.gsub!(/ /,'')
      puts "Mapping #{from} -> #{to}"
      ($custom_maps[from] ||= {})[to] = code
      $custom_frees[to] = free_code
    elsif state.in_class > 0 and state.in_func == false and @str.skip(/%flag\s+([a-z0-9_A-Z]+)/)
    	flag = ("flag_"+@str[1]+"=").intern
    	if stack.last.respond_to?(flag)
	   stack.last.__send__(flag, true)
	else
	   raise "%flags directive cannot be used here (#{stack.last.class} doesn't respond to #{flag})"
	end
    elsif state.in_class > 0 and state.in_func == false and @str.skip(/%feature\s+([a-z0-9_A-Z]+)/)
    	flag = ("feature_"+@str[1]).intern
        @str.skip(/\s+/)
	args = []
        if @str.skip(/\(/)
          args = @str.scan_until(/\)/)[0..-2].split(/, */).map { |i| i.strip }
        end
	@str.skip(/;/)
    	if stack.last.respond_to?(flag)
	   stack.last.__send__(flag, *args)
	else
	   raise "%feature '#{@str[1]}' directive cannot be used here (#{stack.last.class} doesn't support it)"
	end
    elsif @str.skip(/%/) # Skip single-line comment
      @str.skip_until(/\n/) 
      
      
    ####### Comments    
      
    elsif state.in_func == false and @str.skip(/#.*/) # Comment
    	
    elsif state.in_func == false and @str.skip(/\/\/.*/) # Comment
    	
    elsif state.in_func == false and @str.skip(/\/\*(.|\n)*\*\//) # Multi-line Comment
    	
      
    
    ####### Code
    
    elsif txt = @str.scan(/['"]/) #' Skip quoted string
      txt += @str.scan_until(/(^|[^\\])#{txt}/) # Skip until unescaped quote
      func.text += txt if state.in_func
    elsif state.in_func == false and @str.skip(/module(?= )/x) # Module defn
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      @classes[name] = C_Module.new(name, [], [], [])
      @classes[name].parent = stack.last
      stack.last.classes.push(@classes[name])
      stack.push(@class = @classes[name])
      puts "module "+ @class.fullname + "-#{@class.name}"
      state.in_class += 1
    elsif state.in_func == false and @str.skip(/class(?= )/x) # Class defn
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      superclass = nil
      @str.skip(/\s*/)
      if @str.skip(/</)
        @str.skip(/\s*/)
        superclass = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      end
      @classes[name] = C_Class.new(name, superclass, [], [], [])
      @classes[name].parent = stack.last
      stack.last.classes.push(@classes[name])
      stack.push(@class = @classes[name])
      puts "class "+ @class.fullname
      state.in_class += 1
      
    elsif state.in_func == false and @str.skip(/struct(?= )/x) # Ruby Struct
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      @str.skip(/\s+/)
      if @str.skip(/\(/)
        args = @str.scan_until(/\)/)[0..-2].split(/, */).collect { |i| i.strip }
      end
      # NB. struct Name(arg0...argN)
      if @str.skip(/\s*;/)
        stack.last.classes.push(C_Struct.new(name, args, stack.last))
      else
        @classes[name] = C_Struct.new(name, args, stack.last)
        stack.last.classes.push(@classes[name])
        stack.push(@class = @classes[name])
        puts "struct "+ @class.fullname
        state.in_class += 1        
      end
    elsif state.in_func == false and @str.skip(/gcpool(?= )/x) # GC Pool
      @str.skip(/\s+/)
      name = @str.scan(/[a-z_0-9A-Z]*/)
      puts "GCPool #{name}"
      stack.first.classes.push(C_GCRefPool.new(name))
      
    elsif state.in_func == false and @str.skip(/(enum|flags)(?= )/x) # C Enum as module wrapper
      what = @str[1]
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      @str.skip(/\s+/)
      if @str.skip(/\(/)
        args = @str.scan_until(/\)/)[0..-2].split(/, */).collect { |i| i.strip }
      end
      if what == "flags"
      	stack.last.classes.push(C_Flags.new(name, args, stack.last))
      else
      	stack.last.classes.push(C_Enum.new(name, args, stack.last))
      end

    elsif state.in_func == false and @str.skip(/(genum|gflags)(?= )/x) # C GEnum as module wrapper
      what = @str[1]
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      @str.skip(/\s+/)
      g_type = @str.scan(/[A-Z][_0-9A-Z]*/)
      @str.skip(/\s+/)
      prefix = @str.scan(/[A-Z][_0-9A-Z]*/)
      @str.skip(/\s*;/)
      if what == "gflags"
        stack.last.classes.push(C_GFlags.new(name, g_type, prefix, stack.last))
      else
        stack.last.classes.push(C_GEnum.new(name, g_type, prefix, stack.last))
      end
      
    elsif state.in_func == false and @str.skip(/(gobject|ginterface|gboxed)(?= )/x) # Class defn
      type=@str[1]
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      superclass = nil
      @str.skip(/\s*/)
      if @str.skip(/\</)
        @str.skip(/\s*/)
        gtype = @str.scan(/[A-Z_]+/)
      end
      @str.skip(/\s*/)
      if @str.skip(/:/)
        @str.skip(/\s*/)
        gparent_class = @str.scan(/[A-Z_:a-z0-9]+/)
      end
      case type 
      when "gobject"
        @classes[name] = C_GObject.new(name, gtype, [], [], [])
      when "ginterface"
        @classes[name] = C_GInterface.new(name, gtype, [], [], [])
      when "gboxed"
        @classes[name] = C_GBoxed.new(name, gtype, [], [], [])
      else
        raise "#{name} is not a GObject or GInterface..."
      end
      @classes[name].gparent_class = gparent_class
      @classes[name].parent = stack.last
      stack.last.classes.push(@classes[name])
      stack.push(@class = @classes[name])
      puts "class "+ @class.fullname
      state.in_class += 1
	elsif @str.scan(/@type\s+([A-Za-z_0-9]+)/)
		type = @str[1]
		prev = stack.last
		if prev.is_a?(C_GObject) 
			#	p c_type, self
			puts "Converting #{type}* to & from VALUE"
			prev.c_type_name = type
 			($custom_maps[type+'*'] ||= {})["VALUE"] = "GOBJ2RVAL(%%)"
   			($custom_maps["VALUE"] ||= {})[type+'*'] = "RVAL2GOBJ(%%)"
		elsif prev.is_a?(C_GBoxed)
			prev.c_type_name = type

 			($custom_maps[type+'*'] ||= {})["VALUE"] = "BOXED2RVAL(%%, #{prev.superclass})"
   			($custom_maps["VALUE"] ||= {})[type+'*'] = "RVAL2BOXED(%%, #{prev.superclass})"
		else
			# Invalid type directive
		end
    elsif @str.skip(/end(?=\s)/x)
      last = stack.pop
      puts "#{last.class} - #{last.name}"
      case last
      when C_Module, C_Class, C_Enum, C_Flags, C_Struct, C_GObject, C_GInterface, C_GBoxed
        state.in_class -= 1
        @class = stack.last
      when C_Function
        state.in_func = false
     else
        STDERR.puts "Remaining code: #{@str.rest}"
        STDERR.puts "Defined Classes: #{@classes.keys.join(', ')}"
        p stack
        raise "Invalid stack entry #{last.class}"
      end
    elsif @str.skip(/alias\s+:([A-Za-z0-9_]*[\[\]]{0,2}[?!=]?)\s+:([A-Za-z0-9_]*[\[\]]{0,2}[?!=]?)/) # Alias
      @class.add_alias(@str[1], @str[2]) if @class.respond_to?(:add_alias)
    elsif @str.skip(/(pre|post)_func\s+do/)
		where = @str[1]
		str = @str.scan_until(/\bend/)#[0,-4]
		unless str
			raise "Invalid #{where}_func definition: #{@str.peek(200).inspect}"
		end
		str = str[0..-4].strip
		except = only = nil
		@str.skip(/\s*/)
		if @str.skip(/,\s*:(only|except)\s*=\>\s*(\[[^\]]+\])/)
			if @str[1] == 'only'
				only = eval(@str[2]).map{|i|i.to_s}
			else
				except = eval(@str[2]).map{|i|i.to_s}
			end
		end
		if where == 'pre'
			@class.pre_func = str
			@class.pre_only = only if only
			@class.pre_except = except if except
		else
			@class.post_func = str
			@class.post_only = only if only
			@class.post_except = except if except
		end
    elsif @str.skip(/pre_func\s+(.*)/) # Pre func code
      @class.pre_func= @str[1] if @class.respond_to?(:pre_func)
    elsif @str.skip(/post_func\s+(.*)/) # Post func code
      @class.post_func= @str[1] if @class.respond_to?(:post_func)
    elsif @str.skip(/def(?=\s+)/x) # Function defn
      @str.skip(/\s+/)
      if @str.scan(/([a-zA-Z_* ]+):/)
        returntype = @str[1]
      else
        returntype = 'VALUE'
      end
      prename = ''
      prename = @str.scan(/self\./)
      name = @str.scan(/[a-z_0-9A-Z.]+[?!=]?/)
      unless name
        name = @str.scan(/[-\[\]<>~=+|&]{1,3}/)
      end
       name = prename.to_s + (oname=name)
      #p [prename, oname, name]
      @str.skip(/\s*/)
      args = scan_args().collect { |i| C_Param.new(i) }
      func = @functions[name] = C_Function.new(name, args, '')
      func.returntype = returntype
      func.parent = @class
      stack.last.functions.push(func)
      puts "def "+ func.fullname
      stack.push(func)
      state.in_func = true
      
    elsif state.in_func == false and @str.skip(/(string|integer|float|double|int)(?= )/x) # C String as module wrapper
      type= @str[1]
      @str.skip(/\s+/)
      name = @str.scan(/[A-Z][a-z_0-9A-Z]*/)
      @str.skip(/\s*=\s*/)
      if @str.skip(/"/) #"
        string = '"' + @str.scan_until(/[^\\]?"/)  #"
      elsif t = @str.scan(/([A-Z][a-z_0-9A-Z]*)/)
      	string = @str[1]
      elsif type =~ /^(flo|dou|int)/ and t = @str.scan(/([0-9]+(\.[0-9]+)?(e[0-9]+)?)/)
      	string = @str[1]
      end
      klass = nil
      case type
      when /^str/
      	klass = C_String
      when /^int/
        klass = C_Integer
      when /^(flo|dou)/
        klass = C_Float
      end
      stack.last.classes.push(klass.new(name, string, stack.last)) if klass
      
    elsif txt = @str.get_byte # Spare chars
      if state.in_func
        func.text += txt
      else
      	puts '"' << txt << '"'
      end
    end
  end
end
end

end # m Rubber
