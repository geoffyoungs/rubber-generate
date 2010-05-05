require 'rubber/struct'
module Rubber
def generate_c_source(scanner, io)
  mod = scanner.stack.first # Pseudo root module for file
  if scanner.options.gnu
  	io.puts "#define _GNU_SOURCE 1"
  end
  io.puts "/* Includes */"
  io.puts "#include <ruby.h>"
  io.puts "#include <stdlib.h>"
  io.puts "#include <stdio.h>"
  io.puts "#include <string.h>"
  if scanner.incs
    scanner.incs.each { |i| io.puts "#include #{i.inspect}"}
  end
  io.puts "\n/* Setup types */"
  io.puts "/* Try not to clash with other definitions of bool... */"
  io.puts "typedef int rubber_bool;"
  io.puts "#define bool rubber_bool"
  io.puts "\n/* Prototypes */"
  io.puts '#include "rbglib.h"' if scanner.options.glib?
  
if scanner.options.glib? and scanner.options.gtk?
  io.write <<-EOI
#include "rbgtk.h"

#if defined(G_PLATFORM_WIN32) && !defined(RUBY_GTK2_STATIC_COMPILATION)
#  ifdef RUBY_GTK2_COMPILATION
#    define RUBY_GTK2_VAR __declspec(dllexport)
#  else
#    define RUBY_GTK2_VAR extern __declspec(dllimport)
#  endif
#else
#  define RUBY_GTK2_VAR extern
#endif

RUBY_GTK2_VAR VALUE mGtk;
RUBY_GTK2_VAR VALUE mGdk;

#define RBGTK_INITIALIZE(obj,gtkobj)\
 (rbgtk_initialize_gtkobject(obj, GTK_OBJECT(gtkobj)))
EOI
end


  mod.classes.each { |c|
    c.declare(io)
  }
  if scanner.raw
    io.puts("\n/* Inline C code */")
    io.write(scanner.raw)
  end
  io.puts "\n/* Code */"
  mod.classes.each { |c|
    c.code(io)
  }
  io.puts "/* Init */"
  io.puts "void"
  io.puts "Init_#{scanner.ext}(void)"
  io.puts "{"
  io.puts scanner.pre_init_code if scanner.pre_init_code
    mod.classes.each { |c|
      c.register(io)
    }
  io.puts scanner.post_init_code if scanner.post_init_code
  io.puts "}"
  
end
module_function :generate_c_source

module RegisterChildren
	attr_reader :child_names
	def register_children(io)
	    @child_names = {}
	    contents.each { |f| 
    		f.register(io, @child_names.has_key?(f.name)) 
		if @child_names.has_key?(f.name)
			puts "#{self.cname} has duplicate definitiion of #{f.name}"
		else
    		@child_names[f.name]= f 
		end
	    }
	    if respond_to?(:register_aliases)
	    	register_aliases(io)
	    end
	end
	def cname
		if parent && parent.child_names && parent.child_names[name] && parent.child_names[name] != self
			parent.child_names[name].cname 
		else
			default_cname()
		end
	end
end


class C_RootModule
  define_members({:classes => []}, {:methods => []}, {:functions => []}, {:constants => []}, {:includes => []})
  attr_reader :child_names
  def cname
  	p "RootModule cName req'd.", caller
  	nil
  end
end

require 'rubber/codegen/module'
require 'rubber/codegen/class'
require 'rubber/codegen/param'
require 'rubber/codegen/function'

# Constants
require 'rubber/codegen/string'
require 'rubber/codegen/integer'
require 'rubber/codegen/float'

# Special
require 'rubber/codegen/struct'
require 'rubber/codegen/enum'
require 'rubber/codegen/flags'
# needs int derivative
require 'rubber/codegen/genum'
require 'rubber/codegen/gflags'
require 'rubber/codegen/gboxed'
require 'rubber/codegen/ginterface'
require 'rubber/codegen/gobject'

# Utils
require 'rubber/codegen/gcrefpool'


end # m Rubber
