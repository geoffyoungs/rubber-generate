= Rubber Generate =
== v 0.0.5 ==
 
Template language for generating Ruby bindings for C libraries
by Geoff Youngs <g@intersect-uk.co.uk>

=== Introduction ===

A simple ruby-style bindings generator for Ruby.  It allows bindings to 
be laid out in a Ruby style, documentation to be included inline and 
explicit type casts within C code.  It's somewhere between SWIG and pyrex.

It also allows features extconf.rb creation, including checks for headers,
pkg-config etc.  The modules it creates currently depend on Ruby/GTK, but
it is planned to remove this dependency unless they genuinely require Ruby/GTK.

Other features include custom named type-maps, pre/post code inclusion within
functions and some rudimentary understanding of C code.

=== Dependencies ===

 * Ruby 1.8.6

=== Example ===

Sample file:
  example/vte.cr

Usage:
  $ rubber-generate --generate --build vte.cr

Which should generate
  [arch]/vte.c      <- Source code for extension
  [arch]/vte.rd     <- RD documentation from vte.cr
  [arch]/extconf.rb <- Config script
  [arch]/vte.o      <- Object file
  [arch]/vte.so     <- Compiled extension

=== Installation ===

  $ sudo gem install rubber-generate

=== Credits ===

Author: Geoff Youngs

Contributors: 
 * Vincent Isambart
