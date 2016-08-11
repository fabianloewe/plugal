require "./spec_helper"

Plugal.command :test, first: String, second: Int32, result: String
  
class TestProvider
  include Plugal::Provider
  
  provide :test do |first, second|
    "#{first} : #{second}"
  end
end
  
class TestReceiver
  include Plugal::Receiver

  receive :test do |result|
    puts result.data
  end
end

describe Plugal do
  # TODO: Write tests

  it "works" do
    false.should eq(true)
  end
end
