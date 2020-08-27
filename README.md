# coral

Coral is micro-framework for Crystal, inspired by Express and Kemal. It is designed to be both simple and elegant.
To give you an idea of what it looks like, here's a simple "Hello, world!" server:
```crystal
require "coral"

server = Coral::Server.new 8080

server.get "/" do
  Coral::Response.plain "Hello, world!"
end
```
While simple, Coral is powerful. Features so far include:

- Full support for cookies
- Parsing of various form types
- Serving static files and text of various types
- Concurrent requests and the ability to control request capacity
- Full support for multipart file uploads

And upcoming features include:

- Redirects
- Websockets
- HTTPS
- Static directory serving

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  coral:
    github: sugarfi/coral
```

2. Run `shards install`

## Usage

Once you have Coral installed, you should `require` it:
```crystal
require "coral"
```
Now, we can start a simple HTTP server. To do this, we create an instance of the `Coral::Server` object:
```crystal
server = Coral::Server.new 8080
```
The parameters to `Coral::Server#new` are the port number and the request capacity. We don't need to specify
a capacity here, so can just set the port, in this case 8080. Then there are several methods we can use to
add handlers. In this example, we will set up a `GET` handler of `/` that sends the HTML `<h1>Hi!</h1>` to
all clients:
```crystal
server.get "/" do |req|
  Coral::Response.html "<h1>Hi!</h1>
end
```
Here we use a simple block to create a `Coral::Response` object and return it. We also take a `Coral::Request`
as a parameter. We are not limited to just processing `GET` requests. Coral also support most of the other
HTTP methods: `POST`, `PUT`, `DELETE`, `OPTIONS`, `HEAD`, and `PATCH`. As well, we can handle requests on any
path. Finally, we start the server:
```
server.start
```
Then we can navigate to `http://127.0.0.1:8080`, and view our page.

### Responses

There are several other ways to build responses:

- We can use a method like above, passing in a string. The available methods are `Coral::Response#html`, 
  `Coral::Response#plain`, `Coral::Response#json`, `Coral::Response#javascript`, and `Coral::Response#css`.
- We can use one of the above methods followed by `_file` to send a file. For example, to send an HTML file
  named `index.html`, we can use: 
```
Coral::Response.html_file "index.html"
```
- We can create a `Coral::Response` directly. This allows us more control, but is more complex. See the documentation.

### Requests

You may have noticed we did not use the `req` parameter above. However, it has several properties we can access:

- The `cookies` property can be read, and represents the request cookies.
- The `method`, `path`, and `headers` properties will be set to the request method, path, and headers. Note that `headers`
  is case sensitive: `Content-Type` might be set while `content-type` is not.
- The `body` property contains the request body. On supported content types, it will be parsed. Otherwise it is a raw string.
  Supported types are:
    - JSON, parses to a `JSON::Any`
    - URL encoded, parses to a `Hash(String, String)`.
- When a request is encoded using multipart encoding, its body will be parsed for files, and the `files` property will be set
  to those files. It is a `Hash(String, Coral::MultipartFile)`. The `MultipartFile` object will have the properties `filename`,
  `type`, and `body`.

### Custom Body Parsers

As noted above, various body parsers can be used on request bodies. However, only JSON and URL encoded bodies are supported
currently. To add our own body parsers, we first define a body parser class:
```crystal
class MyBodyParser < Coral::BodyParser
  def self.parse(body)
    <parse body>
  end
end
```
Then we can use `server.set_parser <mime_type>, MyBodyParser`, where `<mime_type>` is the MIME type we want to parse.

## Contributing

1. Fork it (<https://github.com/sugarfi/coral/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [sugarfi](https://github.com/sugarfi) - creator and maintainer
