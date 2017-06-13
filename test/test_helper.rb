require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'minitest/autorun'

require_relative 'lib/slightish_test'
require 'slightish'
