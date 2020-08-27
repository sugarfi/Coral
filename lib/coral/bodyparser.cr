require "json"

# Generic body parser module. Contains implementations of two parsers for request bodies: JSONBodyParser and 
# URLBodyParser. They parse JSON and URL encoded data, respectively.
module Coral
    private alias URLMap = Hash(String, String)

    # Base class for all body parsers. Not meant to have a constructor; a good body parser should only expose the 
    # `#self.parse` method. Even this method is not meant to be called directly; it should be bound in the server
    # to a specific MIME type, and then it can be parsed automatically.
    class BodyParser
        def self.parse(body : String)
            raise NotImplementedError.new
        end
    end

    # Body parser for JSON requests. Simply invokes `JSON#parse`, and returns a `JSON::Any` object.
    class JSONBodyParser < BodyParser
        def self.parse(body : String)
            JSON.parse body
        end
    end

    # Body parser for URL encoded requests. Splits each request on the characters "&" and "=" to generate a 
    # `Hash(String, String)` representing passed URL parameters.
    #
    # TODO: add support for array URL parameters, for example: a[]=1&a[]=2. Ideally these could be represented as arrays
    # of strings.
    class URLBodyParser < BodyParser
        def self.parse(body : String)
            body = body.split '&'
            m = URLMap.new
            body.each do |pair|
                k, v = pair.split '='
                m[k] = (v.split '\u0000')[0] # FIXME: relic from testing, when data would be padded to 1024 bytes with 0s.
            end
            m
        end
    end
end