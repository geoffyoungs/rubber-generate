require 'rubber/struct'
require 'rubber/version'
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

  class TokenStringScanner < StringScanner
    def skip(*args)
      x = super
      #p [x, *args] if x
      x
    end
    def scan(*args)
      x = super
      #p [x, *args] if x
      x
    end
    def scan_number
      scan(/(0x[0-9A-Fa-f]+|[0-9]+[.][0-9]+(e[0-9]+)?|[0-9]+)/)
    end
    def scan_lit_string
      scan(/(".*?[^\\]")/)
    end
    def scan_float
      scan(/(\d[.]\d+)/)
    end
    def scan_lit_integer
      scan(/([0-9]+)/)
    end
    def scan_constant
      scan(/([A-Z][a-z_0-9A-Z]*)/)
    end
    def scan_upcase_constant
      scan(/([A-Z][0-9A-Z_]*)/)
    end
    def scan_literal
      scan(/([A-Za-z0-9_]+)/)
    end
    def skip_ws
      skip(/\s+/)
    end
    def scan_nil
      scan(/NULL|nil/i)
    end
    def scan_lit_bool
      scan(/TRUE|FALSE/i)
    end
    def scan_pc_block
      raw = scan_until(/%\}/)
      raw[-2..-1] = ""
      raw
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
      @current_file = file
    end
    attr_reader :current_file
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
      #p @state, @str, ind
      raise
    end
    def _scan(fp)
      @lines = IO.readlines(@file)
      @str = TokenStringScanner.new(@string = @lines.join)
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
          (@raw ||= "") << @str.scan_pc_block
        elsif @str.skip(/%pre_init\{/) # Scan raw
          (@pre_init_code ||= "") << @str.scan_pc_block
        elsif @str.skip(/%post_init\{/) # Scan raw
          (@post_init_code ||= "") << @str.scan_pc_block
        elsif @str.skip_ws # skip
          func.text += " " if state.in_func
        elsif @str.skip(/%name */) # Extension name
          @ext = @str.scan_literal
        elsif @str.skip(/%min-version */)
          @version = @str.scan(/([0-9]+)\.([0-9]+)\.([0-9]+)/)
          version = [1,2,3].map{|i|@str[i].to_i}
          Rubber::VERSION.each_with_index do |ver,idx|
            if ver < version[idx]
              misc_error "This version of rubber-generate (#{Rubber::VERSION}) is too old: #{@file} requires version #{version.map{|i|i.to_s}.join('.')}", false
            end
          end
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
          when 'glib', 'gtk', 'gnu'
            @options[@str[1]] = (@str[2] == 'yes')
          else
            syntax_error "Unknown option #{@str[1]}"
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
            syntax_error "%flags directive cannot be used here (#{stack.last.class} doesn't respond to #{flag})"
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
            syntax_error "%feature '#{@str[1]}' directive cannot be used here (#{stack.last.class} doesn't support it)"
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
          @str.skip_ws
          name = @str.scan_constant
          superclass = nil
          @str.skip(/\s*/)
          if @str.skip(/</)
            @str.skip_ws
            superclass = @str.scan_constant
          end
          @classes[name] = C_Class.new(name, superclass, [], [], [])
          @classes[name].parent = stack.last
          stack.last.classes.push(@classes[name])
          stack.push(@class = @classes[name])
          puts "class "+ @class.fullname
          state.in_class += 1

        elsif state.in_func == false and @str.skip(/struct(?= )/x) # Ruby Struct
          @str.skip_ws
          name = @str.scan_constant
          @str.skip_ws
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
          @str.skip_ws
          name = @str.scan_literal
          puts "GCPool #{name}"
          stack.first.classes.push(C_GCRefPool.new(name))

        elsif state.in_func == false and @str.skip(/(enum|flags)(?= )/x) # C Enum as module wrapper
          what = @str[1]
          @str.skip_ws
          name = @str.scan_constant
          @str.skip_ws
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
          @str.skip_ws
          name = @str.scan_constant
          @str.skip_ws
          g_type = @str.scan_upcase_constant
          @str.skip_ws
          prefix = @str.scan(/(prefix=)?[A-Z][_0-9A-Z]*/i).to_s.sub(/^prefix=/i,'')
          @str.skip_ws
          define_on_self = @str.scan(/define_on_self/)
          @str.skip(/\s*;/)
          if what == "gflags"
            obj = C_GFlags.new(name, g_type, prefix, stack.last)
          else
            obj = C_GEnum.new(name, g_type, prefix, stack.last)
            obj.define_on_self = !! define_on_self;
          end
          stack.last.classes.push(obj)
        elsif state.in_func == false and @str.skip(/(gobject|ginterface|gboxed)(?= )/x) # Class defn
          type=@str[1]
          @str.skip_ws
          name = @str.scan_constant
          superclass = nil
          @str.skip_ws
          if @str.skip(/\</)
            @str.skip_ws
            gtype = @str.scan_upcase_constant
          end
          @str.skip_ws
          if @str.skip(/:/)
            @str.skip_ws
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
            syntax_error "#{name} is not a GObject or GInterface..."
          end
          @classes[name].gparent_class = gparent_class
          @classes[name].parent = stack.last
          stack.last.classes.push(@classes[name])
          stack.push(@class = @classes[name])
          puts "class "+ @class.fullname
          state.in_class += 1
        elsif @str.scan(/@type\s+/)
          type = @str.scan_literal
          prev = stack.last
          if prev.is_a?(C_GObject)
            #  p c_type, self
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
            syntax_error "Invalid stack entry #{last.class}"
          end
        elsif @str.skip(/alias\s+:([A-Za-z0-9_]*[\[\]]{0,2}[?!=]?)\s+:([A-Za-z0-9_]*[\[\]]{0,2}[?!=]?)/) # Alias
          @class.add_alias(@str[1], @str[2]) if @class.respond_to?(:add_alias)
        elsif @str.skip(/(pre|post)_func\s+do/)
          where = @str[1]
          str = @str.scan_until(/\bend/)#[0,-4]
          unless str
            syntax_error "Invalid #{where}_func definition"
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
          if @str.scan(/([a-zA-Z_* 0-9]+):/)
            returntype = @str[1]
          elsif @str.skip(/(GS?List)[{]([^}]+)[}]:/)
            container = @str[1]
            ct = @str[2]
            cn = ct.gsub(/\s+/,'').gsub(/[*]/,'__p')
            rule = container+'{'+ct+'}'
            returntype = rule

            #syntax_error "Auto converting (#{rule}) GSList of #{ct} is not yet supported"
            #  sane
            unless $custom_maps[rule] && $custom_maps[rule]['VALUE']
              function = "rubber_#{container}_of_#{cn}_to_array"
              @raw = @raw.to_s + <<-EOADD
inline VALUE #{function}(#{container} *list) {
              #{container} *p; volatile VALUE ary;
  ary = rb_ary_new();
  for(p = list ; p ; p = p->next) {
    rb_ary_push(ary, #{Rubber.explicit_cast('(('+ct+') p->data )', ct, 'VALUE')});
  }
  return ary;
}
              EOADD
              $custom_maps[rule] ||={}
              $custom_maps[rule]['VALUE'] = function+"(%%)"
            end
          else
            returntype = 'VALUE'
          end
          prename = ''
          prename = @str.scan(/self\./)
          name = @str.scan(/[a-z_0-9A-Z.]+[?!=]?/)
          unless name
            name = @str.scan(/[-\[\]<>~=+|&]{1,3}/)
          end
          oname = name
          name = prename.to_s + oname
          #p [prename, oname, name]
          @str.skip(/\s*/)
          args = scan_args().collect { |i| C_Param.new(i) }
          func = @functions[name] = C_Function.new(name, args, '')
          func.returntype = returntype
          func.parent = @class
          stack.last.functions.push(func)
          puts "def "+ func.fullname
          stack.push(func)
          func.source_line = current_line
          func.source_file = current_file
          state.in_func = true

        elsif state.in_func == false and @str.skip(/(string|integer|float|double|int)(?= )/x) # C String as module wrapper
          type= @str[1]
          @str.skip_ws
          name = @str.scan_constant
          @str.skip(/\s*=\s*/)
          if @str.skip(/"/) #"
            string = '"' + @str.scan_until(/[^\\]?"/)  #"
          elsif t = @str.scan_constant
            string = @str[1]
          elsif type =~ /^(flo|dou|int)/ and t = @str.scan_number #@str.scan(/(0x)?([0-9]+(\.[0-9]+)?(e[0-9]+)?)/)
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
        elsif state.in_func == false && @str.skip(/(array)(?= )/x)
          type = @str[1]
          @str.skip_ws
          name = @str.scan_constant
          @str.skip_ws
          @str.skip(/=/)
          @str.skip_ws
          values = []
          if @str.skip(/\[/)
            @str.skip_ws
            until @str.skip(/\]/)
              if @str.scan_lit_string
                values << { :string => @str[1] } # unescape escaped chars?
              elsif @str.scan_lit_float
                values << { :float => @str[1] }
              elsif @str.scan_lit_integer
                values << { :int => @str[1] }
              elsif @str.skip_nil
                values << { :nil => true }
              elsif @str.scan_lit_bool
                values << { :bool => @str[1].upcase.eql?('TRUE') }
              elsif @str.scan_literal
                values << { :int => @str[1] } # Assume a constant
              else
                syntax_error "Unrecognised array value"
              end
              @str.skip_ws
              @str.skip(/,/)
              @str.skip_ws
            end
            stack.last.classes.push(C_Array.new(name, values, stack.last))
            p [ :create_array, values ]
          else
            syntax_error "Arrays should be in the form: [value1, value2, ... valueN]"
          end
        elsif txt = @str.get_byte # Spare chars
          if state.in_func
            func.text += txt
          else
            syntax_error "Invalid character #{txt}"
          end
        end
      end
    end
    def current_line
      count = 0
      @string[0..@str.pos].each_byte { |b| count += 1 if b == 10 }
      count
    end
    def syntax_error(message)
      STDERR.puts "Syntax Error: #{message} at line #{current_line}\n"
      if @str.rest.size > 255
        STDERR.puts @str.rest[0..255]+"..."
      else
        STDERR.puts @str.rest
      end
      exit 1
    end
    def misc_error(message, show_location=true)
      STDERR.puts "Error: #{message} at line #{current_line}\n"
      if show_location
        if @str.rest.size > 255
          STDERR.puts @str.rest[0..255]+"..."
        else
          STDERR.puts @str.rest
        end
      end
      exit 1
    end

  end

end # m Rubber
