module Rubber
  def self.generate_rd(scanner, io)
    if scanner.doc
      io.write(scanner.doc + "\n\n")
    end
    scanner.stack.first.classes.each { |c|
      c.doc_rd(io)
    }
  end
end
