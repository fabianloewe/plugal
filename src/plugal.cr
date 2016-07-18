require "./plugal/*"

module Plugal
  # TODO Put your code here
end

Plugal.command :love, me: String, you: String, result: String

class MyProvider
  include Plugal::Provider

  def initialize
    @@receiver = "MyReceiver"
  end

  provide :love do |me, you|
    "#{me}+#{you}=LoVe!"
  end
end

class MyReceiver
  include Plugal::Receiver

  receive :love do |result|
    puts result
  end
end

recv = MyReceiver.new
recv.send :love, "Fabi", "Marleen"
