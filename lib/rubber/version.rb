module Rubber
VERSION = [0,0,22]
def VERSION.to_s
	self.map{|i|i.to_s}.join('.')
end
end
