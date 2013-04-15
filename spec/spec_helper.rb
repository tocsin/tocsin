require File.expand_path("../../lib/tocsin", __FILE__)

RSpec.configure do |c|
  c.mock_with :mocha
end

Mail.defaults do
  delivery_method :test
end

class Tocsin::Alert
  attr_accessor :id, :exception, :backtrace, :category, :severity, :message

  def initialize(args = {})
    @id = 1
    @backtrace = args[:backtrace]
    @exception = args[:exception]
    @category  = args[:category]
    @severity  = args[:severity]
    @message   = args[:message]
  end

  def self.create(*args)
    self.new(*args)
  end

  def self.find(*args)
    self.new(*args)
  end
end

class Resque
  def self.enqueue(*args)
  end
end
