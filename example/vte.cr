%include vte/vte.h

%{

VALUE
long_array(long values[], int size)
{
  VALUE arr;
  int i;
  
  arr = rb_ary_new();
  
  for(i=0; i < size; i++)
    rb_ary_push(arr, LONG2NUM(values[i]));
  
  return arr;
}
char **
string_list(VALUE ary)
{
  char **list = NULL;
  int i;
  
  if (NIL_P(ary))
    return NULL;
  
  list = ALLOC_N(char*, RARRAY(ary)->len + 1);
  
  for (i = 0; i < RARRAY(ary)->len; i++)
  {
      list[i] = StringValuePtr(RARRAY(ary)->ptr[i]);
  }
  list[i] = NULL;
  
  return list;
}

%}


%name vte
%pkg-config vte

%map VALUE > fontdescription : ((PangoFontDescription*)RVAL2BOXED((%%), PANGO_TYPE_FONT_DESCRIPTION))
%map fontdescription > VALUE : (BOXED2RVAL((void*)(%%), PANGO_TYPE_FONT_DESCRIPTION))

%map VALUE > GdkColor* : ((GdkColor*)RVAL2BOXED((%%), GDK_TYPE_COLOR))
%map GdkColor* > VALUE : (BOXED2RVAL((void*)(%%), GDK_TYPE_COLOR))

%map long* > VALUE : long_array(%%, (sizeof(%%) / sizeof(%%[0])))
%map VALUE > char** : string_list(%%)

%map GdkPixbuf* > VALUE : GOBJ2RVAL(%%)
%map VALUE > GdkPixbuf* : GDK_PIXBUF(RVAL2GOBJ(%%))


=begin
= VTE Terminal Widget

The VTE widget is a new terminal widget meant to replace zvt. It is used by gnome-terminal as of GNOME 2.2.x 

== Features
=== Unicode support 
Recently added support for UTF-8 display, select and paste. Currently supports fixed-width, iso10646-encoded and wide fonts. 

=== Background pixmaps 
A very fast implementation of background pixmaps and pseudo-transparency means all users can have beautiful desktops without heavily impacting their work. 

=== Secure and portable 
Only a small external program is required to interact directly with the operating system and pseudo tty interface. This is easily ported to different Unix systems and auditable for security. 

=== Easy to use and feature rich 
Through a simple api adding a complete terminal execution environment to any application (including secure tty setup and utmp/wtmp logging) is next to trivial (3-4 function calls). It can also be used as a direct text display engine with colour/attributes and cursor addressible display without the need for a separate sub-process. 

Features include configurable colours, pixmaps/transparency, beeps, blinking cursor, selecting by word characters, and more. Plus all the usual stuff like selection/pasting, and scrollback buffer. 

=== xterm compatible 
It aims towards being a terminal-compatible dropin for the xterm program. This is to aid interoperability with foreign systems. The rarely used Tektronix graphics terminal component has been dropped however. 

=== Dingus Click 
Allows auto highlighting of a set of text matching a regular expression. Used by the gnome-terminal to launch a web-browser when the user shift-clicks on a URL. 

=== Actively developed 
Steadily improving feature set and stability. 

=end
module VTE
  gobject Terminal < VTE_TYPE_TERMINAL : Gtk::Widget
    def initialize()
=begin
  Create a new terminal widget
  
  * Returns: new instance of VTE::Terminal
=end
      RBGTK_INITIALIZE(self, vte_terminal_new());
    end
    
    def uint:fork_command(char *command, char ** argv, char ** envv, char *dir, bool lastlog = FALSE, bool utmp = FALSE, bool wtmp = FALSE)
=begin
  Fork the child process for the terminal, e.g. terminal.fork_command("/bin/sh", nil, nil, ENV['HOME'])
  
  * Returns: pid of child process
=end
      pid_t pid = 0;
      
      pid = vte_terminal_fork_command(VTE_TERMINAL(_self), command, argv, envv, dir,
          lastlog, utmp, wtmp);
      
      if (argv)
        free(argv);
      if (envv)
        free(envv);
      
      return pid;
    end
    
    def feed(T_STRING str)
=begin
  Send data to the terminal
=end
      vte_terminal_feed(VTE_TERMINAL(_self), RSTRING(str)->ptr, RSTRING(str)->len);
    end
    
    def feed_child(T_STRING str)
=begin
  Send data to the child process
=end
      vte_terminal_feed_child(VTE_TERMINAL(_self), RSTRING(str)->ptr, RSTRING(str)->len);
    end
    
    def cursor_position()
=begin
  Get the current cursor position
=end
      long arr[2];
      vte_terminal_get_cursor_position(VTE_TERMINAL(_self), &arr[0], &arr[1]);
      return <arr:ruby>;
    end
    
    def get_padding()
=begin
  Get the padding the widget is using.
=end
      long arr[2];
      vte_terminal_get_padding(VTE_TERMINAL(_self), (int*)&arr[0], (int*)&arr[1]);
      return <arr:ruby>;
    end
    
#################### Misc settings
    def scrollback_lines=(long lines)
=begin
  Set the number of scrollback lines, above or at an internal minimum.
=end
      vte_terminal_set_scrollback_lines(VTE_TERMINAL(_self), lines);
    end
    
    def set_size(long x, long y)
=begin
  Set the terminal size.
=end
      vte_terminal_set_size(VTE_TERMINAL(_self), x, y);
    end
    
    def cursor_blinks=(bool blink)
=begin
  Set whether or not the cursor blinks.
=end
      vte_terminal_set_cursor_blinks(VTE_TERMINAL(_self), blink);
    end
    
    def reset(bool full=TRUE, bool clear_history=TRUE)
=begin
  Reset the terminal, optionally clearing the tab stops and line history.
=end
      vte_terminal_reset(VTE_TERMINAL(_self), full, clear_history);
    end
    
#################### Fonts
    def bool:using_xft?()
=begin
  Is the terminal using Xft to render text?
  
  * Returns: Boolean
=end
      return vte_terminal_get_using_xft(VTE_TERMINAL(_self));
    end
    
    def font=(VALUE font)
=begin
  Set the terminal font.
  ((|font|)) is either a String or Pango::FontDescription
=end
      if (TYPE(font) == T_DATA)
        vte_terminal_set_font(VTE_TERMINAL(_self), <font:fontdescription>);
      else
        vte_terminal_set_font_from_string(VTE_TERMINAL(_self), <font:string>);
    end
    
    def fontdescription:font()
=begin
  Get the terminal's current font description.
  
  * Returns: Pango::FontDescription
=end
      return vte_terminal_get_font(VTE_TERMINAL(_self));
    end
    
    def bool:allow_bold?()
=begin
  Check whether the terminal allows bold text?
  
  * Returns: Boolean
=end
      return vte_terminal_get_allow_bold(VTE_TERMINAL(_self));
    end
    
    def allow_bold=(bool allow)
=begin
  Set whether the terminal allows bold text
=end
      vte_terminal_set_allow_bold(VTE_TERMINAL(_self), allow);
    end
    
#################### Clipboard
    def copy()
=begin
  Copy the current selection to the clipboard
=end
      vte_terminal_copy_clipboard(VTE_TERMINAL(_self));
    end
    def paste()
=begin
  Paste the current clipboard contents into the terminal
=end
      vte_terminal_paste_clipboard(VTE_TERMINAL(_self));
    end
    def copy_primary()
=begin
  Copy the current selection as the primary selection
=end
      vte_terminal_copy_primary(VTE_TERMINAL(_self));
    end
    def paste_primary()
=begin
  Paste the current primary selection into the terminal
=end
      vte_terminal_paste_primary(VTE_TERMINAL(_self));
    end
    def bool:has_selection?()
=begin
  Paste the current primary selection into the terminal
=end
      return vte_terminal_get_has_selection(VTE_TERMINAL(_self));
    end

#################### Mouse
    def mouse_autohide=(bool hide)
=begin
  Paste the current primary selection into the terminal
=end
      vte_terminal_set_mouse_autohide(VTE_TERMINAL(_self), hide);
    end
    
    def bool:mouse_autohide?()
=begin
  Paste the current primary selection into the terminal
=end
      return vte_terminal_get_mouse_autohide(VTE_TERMINAL(_self));
    end

#################### Matched text
    def int:match_add(T_REGEXP text)
=begin
  Add a matching expression, returning the tag the widget assigns to that expression
=end
      return vte_terminal_match_add(VTE_TERMINAL(_self), RREGEXP(text)->str);
    end
    
    def match_remove(int tag)
=begin
  Remove a matching expression by tag
=end
      vte_terminal_match_remove(VTE_TERMINAL(_self), tag);
    end
    def match_check(long column, long row)
=begin
  Check for a matched tag at a given position
=end
      char *text;
      int tag;
      
      text = vte_terminal_match_check(VTE_TERMINAL(_self),
			       column, row,
			       &tag);
      if (text)
        return rb_ary_new3(2, <text:ruby>, <tag:ruby>);
      else
        return Qnil;
    end

#################### Properities
    def gobject:adjustment()
=begin
  * Returns: the Gtk::Adjustment for the widget
=end
      return vte_terminal_get_adjustment(VTE_TERMINAL(_self));
    end
    def string:title()
=begin
  * Returns: the terminal's title
=end
      return vte_terminal_get_window_title(VTE_TERMINAL(_self));
    end
    def string:icon_title()
=begin
  * Returns: the terminal's icon title
=end
      return vte_terminal_get_icon_title(VTE_TERMINAL(_self));
    end
    def long:char_width()
      return vte_terminal_get_char_width(VTE_TERMINAL(_self));
    end
    def long:char_height()
      return vte_terminal_get_char_height(VTE_TERMINAL(_self));
    end
    def long:char_ascent()
      return vte_terminal_get_char_ascent(VTE_TERMINAL(_self));
    end
    def long:char_descent()
      return vte_terminal_get_char_descent(VTE_TERMINAL(_self));
    end
    def long:row_count()
      return vte_terminal_get_row_count(VTE_TERMINAL(_self));
    end
    def long:column_count()
      return vte_terminal_get_column_count(VTE_TERMINAL(_self));
    end
    
################### Fancy backgrounds
    def background_image=(T_DATA|T_STRING image)
      if (TYPE(image)==T_STRING)
        vte_terminal_set_background_image_file(VTE_TERMINAL(_self),
					    StringValuePtr(image));
      else
        vte_terminal_set_background_image(VTE_TERMINAL(_self), <{VALUE>GdkPixbuf*:image}>);
    end
    alias :set_background_image :background_image=
    
    def set_color_background(GdkColor *color)
        vte_terminal_set_color_background(VTE_TERMINAL(_self),
					    color);
    end
    alias :background_color= :set_color_background
    
    def set_color_foreground(GdkColor *color)
        vte_terminal_set_color_foreground(VTE_TERMINAL(_self),
					    color);
    end
    alias :foreground_color= :set_color_foreground
    
    def set_background_saturation(double saturation)
        vte_terminal_set_background_saturation(VTE_TERMINAL(_self), saturation);
    end
        
  end
end
