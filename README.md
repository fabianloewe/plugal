# Plugal

A plugin system relying on Redis in Crystal

Beside that you can also use it to simply communicate with other processes or applications
over commands in a type-safer way.

## Installation

Install Redis. For information on how to do that have a look at http://redis.io.

Then add this to your application's `shard.yml`:

```yaml
dependencies:
  plugal:
    github: hyronx/plugal
```


## Usage


```crystal
require "plugal"
```

Define a command. It follows the style of `JSON#mapping`.
```crystal
Plugal.command :love, me: String, you: String
```

Create a provider which includes `Plugal::Provider`.
```crystal
class MyProvider
  include Plugal::Provider

  def initialize
    @@receiver = "MyReceiver"
  end

  provide :love do |me, you|
    "#{me}+#{you}=LoVe!"
  end
end
```

Now you can create an instance of your class and run it.
This will already be the first application and could serve as a plugin.
```crystal
prov = MyProvider.new
prov.run
```


To receive the data provided by the first class you need a receiver. Quelle surprise!
Include `Plugal::Receiver` and use the `Plugal::Receiver#receive` macro to get your result.
```crystal
class MyReceiver
  include Plugal::Receiver

  receive :love do |result|
    puts result.data  # => e.g. "Victor+Chantel=LoVe!"
  end
```

There are some things to notice. You don't directly get your resulting data but a wrapper containing it.
The `Plugal::Result` class can also signal you failure so you can handle errors. For more information check the docs.

Again an instance must be created and run. This application will receive data from all providers connected to it.
```crystal
recv = MyReceiver.new
recv.run
```

## Development

1. Do a lot more testing
2. Figure out useful features

## Contributing

1. Fork it ( https://github.com/hyronx/plugal/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [hyronx](https://github.com/hyronx) Fabian Loewe - creator, maintainer
