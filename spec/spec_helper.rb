require File.expand_path("../../lib/tocsin", __FILE__)

RSpec.configure do |c|
  c.mock_with :mocha
end

Mail.defaults do
  delivery_method :test
end

class Tocsin::Alert
  def id
    1
  end

  def category
  end

  def severity
  end

  def self.create(*args)
    self.new
  end

  def self.find(*args)
    self.new
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end
end

class Resque
  def self.enqueue(*args)
  end
end
