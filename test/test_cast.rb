$: << 'lib'

require 'test/unit'
require 'rubber/types'

class TestCast < Test::Unit::TestCase
	def test_uint64
		assert_equal "rb_ull2inum(foo)",
			Rubber.explicit_cast('foo', 'uint64', 'VALUE').strip
		assert_equal "rb_ull2inum(foo)",
			Rubber.explicit_cast('foo', 'guint64', 'VALUE').strip

		assert_equal "rb_num2ull(foo)",
			Rubber.explicit_cast('foo', 'VALUE', 'guint64').strip
	end
end

