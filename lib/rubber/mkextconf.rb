
module Rubber
def generate_extconf(scanner, io)
	io.write <<-EOMK
require 'mkmf'
use_gems = false
begin
  require 'mkmf-gnome2'
rescue LoadError
  use_gems = true
end

if use_gems or Object.const_defined?('Gem')
  require 'rubygems'
  gem 'glib2'
  require 'mkmf-gnome2'
  %w[rbglib.h rbgtk.h rbpango.h rbatk.h].each do |header|
  	Gem.find_files(header).each do |f|
		$CFLAGS += " '-I\#{File.dirname(f)}'"
	end
  end
end
EOMK

io.write <<-EOMK
# Look for headers in {gem_root}/ext/{package}
if use_gems
  %w[
EOMK
  io << " glib2" if scanner.options.glib
  io << " gdk_pixbuf2 atk gtk2" if scanner.options.gtk
  io.write <<-EOX
].each do |package|
    require package
    if Gem.loaded_specs[package]
      $CFLAGS += " -I" + Gem.loaded_specs[package].full_gem_path + "/ext/" + package
    else
      if fn = $".find { |n| n.sub(/[.](so|rb)$/,'') == package }
        dr = $:.find { |d| File.exist?(File.join(d, fn)) }
        pt = File.join(dr,fn) if dr && fn
      else
        pt = "??"
      end
      STDERR.puts "require '" + package + "' loaded '"+pt+"' instead of the gem - trying to continue, but build may fail"
    end
  end
end
EOX

io.write <<-EOY
if RbConfig::CONFIG.has_key?('rubyhdrdir')
  $CFLAGS += " -I" + RbConfig::CONFIG['rubyhdrdir']+'/ruby'
end

$CFLAGS += " -I."
have_func("rb_errinfo")
EOY

    if scanner.inc_dirs
      io.puts "$CFLAGS += "+scanner.inc_dirs.reject { |i| i =~ /:/ }.collect { |i| " '-I#{i}'" }.join().inspect
      scanner.inc_dirs.select { |i| i =~ /gem:/ }.each do |gem_info|
        name,extra = gem_info.split(/:/)[1].split(%r'/', 2)
        extra = "/#{extra}" unless extra.nil? or extra.empty?
        io.puts %Q<gem '#{name}'; $CFLAGS += "  '-I" + Gem.loaded_specs['#{name}'].full_gem_path + "#{extra}'">
      end
    end
    if scanner.lib_dirs
      io.puts "$LDFLAGS += "+scanner.lib_dirs.collect { |i| " '-L#{i}'"}.join().inspect
    end
    if scanner.defs
      io.puts "$CFLAGS += "+scanner.defs.collect { |i| " '-D#{i}'"}.join().inspect
    end
    scanner.pkgs.each { |pkg| io.puts "PKGConfig.have_package(#{pkg.inspect}) or exit(-1)" } if scanner.pkgs
    
    if scanner.incs
      scanner.incs.each { |i|
        io.puts %Q<
unless have_header(#{i.inspect})
  paths = Gem.find_files(#{i.inspect})
  paths.each do |path|
    $CFLAGS += " '-I\#{File.dirname(path)}'"
  end
  have_header(#{i.inspect}) or exit -1
end
>
      }
    end
    if scanner.libs
      scanner.libs.each { |i| io.puts "have_library(#{i.inspect}) or exit(-1)\n$LIBS += \" -l#{i}\""}
    end
    io.write <<-EOB

STDOUT.print("checking for new allocation framework... ") # for ruby-1.7
if Object.respond_to? :allocate
  STDOUT.print "yes\n"
  $defs << "-DHAVE_OBJECT_ALLOCATE"
else
  STDOUT.print "no\n"
end

top = File.expand_path(File.dirname(__FILE__) + '/..') # XXX
$CFLAGS += " " + ['glib/src'].map{|d|
  "-I" + File.join(top, d)
}.join(" ")

have_func("rb_define_alloc_func") # for ruby-1.8

#set_output_lib('libruby-#{scanner.ext}.a')
if /cygwin|mingw/ =~ RUBY_PLATFORM
  top = "../.."
  [
    ["glib/src", "ruby-glib2"],
  ].each{|d,l|
    $LDFLAGS << sprintf(" -L%s/%s", top, d)
    $libs << sprintf(" -l%s", l)
  }
end
begin
  srcdir = File.expand_path(File.dirname($0))

  begin

    obj_ext = "."+$OBJEXT

    $libs = $libs.split(/\s/).uniq.join(' ')
    $source_files = Dir.glob(sprintf("%s/*.c", srcdir)).map{|fname|
      fname[0, srcdir.length+1] = ''
      fname
    }
    $objs = $source_files.collect do |item|
      item.gsub(/\.c$/, obj_ext)
    end

    #
    # create Makefile
    #
    $defs << "-DRUBY_#{scanner.ext.upcase}_COMPILATION"
    # $CFLAGS << $defs.join(' ')
    create_makefile(#{scanner.ext.inspect}, srcdir)
    raise Interrupt if not FileTest.exist? "Makefile"

    File.open("Makefile", "a") do |mfile|
      $source_files.each do |e|
        mfile.print sprintf("%s: %s\n", e.gsub(/\.c$/, obj_ext), e)
      end
    end
  ensure
    #Dir.chdir ".."
  end

  #create_top_makefile()
rescue Interrupt
  print "  [error] " + $!.to_s + "\n"
end

    EOB
end
module_function :generate_extconf
end
