
$custom_maps = {}
$custom_frees = {}
$equivalents = {}
module Rubber
# Map most GLib types to normal C style ones
CMAP = { 
  'ruby'=>'VALUE',
  'gboolean'=>'bool', 
  'gint'=>'int', 
  'glong'=>'long', 
  'guint'=>'uint', 
  'gchar'=>'char',
  'gfloat'=>'double', # Ruby only uses doubles?
  'float'=>'double', # Ruby only uses doubles?
  'gdouble'=>'double'
}
class << self
  def auto_class_map()
  hsh = {}
  %w[rb_cObject
rb_cArray
rb_cBignum
rb_cClass
rb_cDir
rb_cData
rb_cFalseClass
rb_cFile
rb_cFixnum
rb_cFloat
rb_cHash
rb_cInteger
rb_cIO
rb_cModule
rb_cNilClass
rb_cNumeric
rb_cProc
rb_cRange
rb_cRegexp
rb_cString
rb_cSymbol
rb_cThread
rb_cTime
rb_cTrueClass
rb_cStruct
rb_eException
rb_eStandardError
rb_eSystemExit
rb_eInterrupt
rb_eSignal
rb_eFatal
rb_eArgError
rb_eEOFError
rb_eIndexError
rb_eRangeError
rb_eIOError
rb_eRuntimeError
rb_eSecurityError
rb_eSystemCallError
rb_eTypeError
rb_eZeroDivError
rb_eNotImpError
rb_eNoMemError
rb_eNoMethodError
rb_eFloatDomainError
rb_eScriptError
rb_eNameError
rb_eSyntaxError
rb_eLoadError].each { |n|
    hsh[$1]= n.strip if n =~ /rb_[ce]([A-Za-z]+)/
  }
  hsh
  end
end
RUBY_CLASS_MAP = auto_class_map()


def self.find_class(classname)
  return nil if classname.nil?
  return RUBY_CLASS_MAP[classname] if RUBY_CLASS_MAP.has_key?(classname)
  # Should this be rb_c or just c?
  # c{NAME} works better... I think...
  return 'c'+classname
end

	RUBY_NATIVE_TYPES = %w|T_NIL T_OBJECT T_CLASS T_MODULE T_FLOAT T_STRING T_REGEXP T_ARRAY T_FIXNUM T_HASH T_STRUCT T_BIGNUM T_FILE T_TRUE T_FALSE T_DATA T_SYMBOL|
	RUBY_NATIVE_NAMES = %w|Nil Object Class Module Float String Regexp Array Fixnum Hash Struct Bignum File True False Data Symbol|

def self.native_type?(name)
  return true if name.nil? or RUBY_NATIVE_TYPES.include?(equivalent_type(name))
  false
end

def self.count_arr_access(str,name)
  if name.include?(?[)
    sc = StringIO.new(name)
    brac, lev = 0, 0
    until sc.eof?
      c = sc.getc
      if lev == 0 and c == ?[
        brac += 1
      end
      case c
      when ?[
        lev += 1
      when ?]
        lev -= 1
      end 
    end
    brac
  else
    0
  end
end

def self.equivalent_type(ctype,name=nil)
    ctype.gsub!(/ /,'')
    ctype.strip!
    ctype.gsub!(/(const|static)/,'')
    if name
      brackets = count_arr_access(ctype,name)
      until brackets == 0
        ctype = ctype[0..-2] if ctype[-1] == ?*
        brackets -= 1
      end
    end
    return 'VALUE' if RUBY_NATIVE_TYPES.include?(ctype)
    ctype= $equivalents[ctype] if $equivalents.has_key?(ctype)
    return 'VALUE' if RUBY_NATIVE_TYPES.include?(ctype)
    ctype= CMAP[ctype] if CMAP.has_key?(ctype)
    ctype
end

def self.explicit_cast(name, ctype, rule)
    ctype = equivalent_type(ctype, name)
    rule = equivalent_type(rule)
    #puts "#{name}:#{ctype}->#{rule}"
    return name if ctype == rule
    if $custom_maps.has_key?(ctype)
      if $custom_maps[ctype].has_key?(rule)
        return $custom_maps[ctype][rule].gsub(/%%/,"#{name}")
      end
    end
    case ctype
    when 'VALUE'
      case rule
        when 'char*', 'string'
          "( NIL_P(#{name}) ? NULL : StringValuePtr(#{name}) )"
        when 'bool'
          "RTEST(#{name})"
        when 'int'
          "NUM2INT(#{name})"
        when 'uint'
          "NUM2UINT(#{name})"
        when 'long'
          "NUM2LONG(#{name})"
        when 'double'
          "NUM2DBL(#{name})"
        when 'gobject', 'GObject*'
          "RVAL2GOBJ(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      #"#{ctype.gsub(/[* ]/,'_').upcase}_TO_#{rule.upcase}(#{name})"
      end
    when 'bool'
      case rule
        when 'char*', 'string'
          "#{name} ? #{"true".inspect} : #{"false".inspect}"
        when 'VALUE', 'ruby'
          " ((#{name}) ? Qtrue : Qfalse)"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      #"#{ctype.gsub(/[* ]/,'_').upcase}_TO_#{rule.upcase}(#{name})"
      end
    when 'uint'
      case rule
        when 'VALUE', 'ruby'
          " UINT2NUM(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      end
    when 'char*', 'string'
      case rule
        when 'VALUE', 'ruby'
          " rb_str_new2(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      end
    when 'GObject*', 'gobject'
      case rule
        when 'VALUE', 'ruby'
          " GOBJ2RVAL(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      end
    when 'int'
      case rule
        when 'VALUE', 'ruby'
          " INT2NUM(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      end
    when 'long'
      case rule
        when 'VALUE', 'ruby'
          " LONG2NUM(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      end
    when 'double'
      case rule
        when 'VALUE', 'ruby'
          " rb_float_new(#{name})"
        else
        raise "Unable to convert #{ctype} to #{rule}"
      end
    else
      raise "Unable to convert #{ctype} to #{rule}"
      #"#{ctype.gsub(/[* ]/,'_').upcase}_TO_#{rule.upcase}(#{name})"
    end
end
end
