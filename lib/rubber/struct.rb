class Class
def define_member(name, value=nil)
    raise "Not a symbol - #{name}" unless name.kind_of?(Symbol)
    if value.nil?
	 module_eval("attr_accessor #{name.inspect}")
    else
	module_eval("attr_writer #{name.inspect};def #{name}(); def self.#{name}(); @#{name}; end; if instance_variables.include?(#{('@'+name.to_s).inspect}) then @#{name} else @#{name} = #{value.inspect}; end; end")
    end
end
def define_members(*ids)
    members = []
    ids.each do |id|
	if id.kind_of?(Hash)
	    STDERR.puts("WARNING: Hash passed to define_members has size > 1 in #{caller.join("\n")}\n`#{to_s}.new(...)' will not work as expected (non-predictable member order)") if id.size > 1
	    id.each do |name,value|
		define_member(name,value)
                raise "Duplicate definition of member `#{name}'" if members.include?(name.to_s)
		members.push(name.to_s)
	    end
	elsif id.kind_of?(Symbol)
	    define_member(id)
            raise "Duplicate definition of member `#{id}'" if members.include?(id.to_s)
	    members.push(id.to_s)
	else
	    raise "Neither a Hash nor a Symbol - `#{id}'"
	end
    end
    module_eval <<-EOS
      def initialize(*ids); 
        members.each_index { |i| __send__((members[i]+'=').intern, i < ids.size ? ids[i] : __send__(members[i].intern)) }; 
          if respond_to?(:init)
            case method(:init).arity
            when 0
              __send__(:init) # Avoid errors if init doesn't need args...
            else
              __send__(:init,*ids)
            end
          end
      end
      def self.new_from_hash(hash,*args); obj=new(*args); hash.each { |n,v| fn = (n.to_s+'=').intern; if obj.members.include?(n.to_s); obj.__send__(fn, v); else raise ArgumentError, 'Unknown member - '+n.to_s; end  }; obj; end
      def self.members(); #{members.inspect}; end
      def members(); #{members.inspect}; end
      def kind_of?(klass); return true if klass == Struct; super(klass); end
      def to_a(); [#{members.join(', ')}]; end
      def [](id); id=id.intern if id.kind_of?(String); case id; #{i=-1;members.collect{|name| "when :#{name},#{i+=1}; @#{name};"}} else raise 'Unknown member - '+id.to_s; end; end
      def []=(id,value); id=id.intern if id.kind_of?(String); case id; #{i=-1;members.collect{|name| "when :#{name},#{i+=1}; @#{name}=value;"}} else raise 'Unknown member - '+id.to_s; end; end
      def length; #{members.size}; end
      alias_method(:size, :length)
      alias_method(:values, :to_a)
    EOS
  end
end
