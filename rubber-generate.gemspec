spec = Gem::Specification.new do |s| 
  s.name = "rubber-generate"
  s.version = "0.0.7"
  s.author = "Geoff Youngs"
  s.email = "g@intersect-uk.co.uk"
  s.homepage = "http://github.com/geoffyoungs/rubber-generate"
  s.platform = Gem::Platform::RUBY
  s.summary = "Template language for generating Ruby bindings for C libraries"
  s.files = Dir["{bin,lib}/**/*"].to_a + ['README.textile']
  s.require_path = "lib"
  s.bindir = 'bin'
  s.executables = ['rubber-generate']
  #s.autorequire = "name"
  s.test_files = ['example/vte.cr']
  #s.has_rdoc = true
  s.extra_rdoc_files = ["README.textile"]
  s.description = <<-EOF
    rubber-c-binder allows a rubyish means of generating bindings for C libraries,
    including (but not limited to) GObject based libraries.

    It allows C code to be written in the context of a ruby style class/method layout
    and eases type checking and conversion between Ruby & C datatypes.
EOF
 #s.add_dependency("dependency", ">= 0.x.x")
end
