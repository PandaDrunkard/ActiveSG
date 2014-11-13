# ActiveSG

A simple ActiveSG client.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ActiveSG'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ActiveSG

## Usage

```
client = ActiveSG.Client.new
client.username = "xxxx"
client.password = "xxxx"

client.login

client.available_slots_on 31/12/2014 289

client.book_slot xxxxxxxx
client.book_slot xxxxxxxx

client.logout
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ActiveSG/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
