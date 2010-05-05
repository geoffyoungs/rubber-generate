
module Rubber
def generate_extconf(scanner, io)
  if true
    io.puts "require 'mkmf'"
    io.puts "require 'mkmf-gnome2'" if scanner.pkgs
    #io.puts "$defs ||= []"

    if scanner.inc_dirs
      io.puts "$CFLAGS += "+scanner.inc_dirs.collect { |i| " '-I#{i}'"}.join().inspect
    end
    if scanner.lib_dirs
      io.puts "$LDFLAGS += "+scanner.lib_dirs.collect { |i| " '-L#{i}'"}.join().inspect
    end
    if scanner.defs
      io.puts "$CFLAGS += "+scanner.defs.collect { |i| " '-D#{i}'"}.join().inspect
    end
    scanner.pkgs.each { |pkg| io.puts "PKGConfig.have_package(#{pkg.inspect}) or exit(-1)" } if scanner.pkgs
    
    if scanner.incs
      scanner.incs.each { |i| io.puts "have_header(#{i.inspect}) or exit(-1)"}
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
end
module_function :generate_extconf
end
