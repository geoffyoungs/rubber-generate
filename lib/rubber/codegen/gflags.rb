require 'rubber/codegen/enum'

module Rubber

class C_GFlags < C_Enum
  define_members :name, :g_type, :prefix, :parent
  def init()
    ($custom_maps[name] ||= {})["VALUE"] = "GFLAGS2RVAL(%%, #{g_type})"
    ($custom_maps["VALUE"] ||= {})[name] = "RVAL2GFLAGS(%%, #{g_type})"
    gt = g_type.dup
    gt.sub!("#{$1}_TYPE","#{$1}") if gt =~ /\A([A-Z]+)_TYPE/ # Strip TYPE bit
    tc = gt.downcase.capitalize.gsub(/_[a-z]/){ |i| i[1..1].upcase}
    #p tc
    ($custom_maps["VALUE"] ||= {})[tc] = "RVAL2GFLAGS(%%, #{g_type})"
  end
  def code(io)
  end
  def declare(io)
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
  def register(io, already_defined=false)
      io.puts "  G_DEF_CLASS(#{g_type}, #{name.inspect}, #{get_root.cname});"
      io.puts "  G_DEF_CONSTANTS(#{parent.cname}, #{g_type}, #{prefix.inspect});"
#    strip = args.first.length - splits.first.length 
  end
end

end # Rubber
