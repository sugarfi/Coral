require "./status"

# Generic response module. Pretty much all this defines is the response class; not very interesting.
module Coral

    # Represents a response. Unlike `Request`, this class is meant to be constructed manually, and should be returned from
    # every handler.
    class Response
        getter status : Status, body : String
        property headers : HeaderMap
        property cookies : CookieMap

        DEFAULTHEADERS = {
            "Content-Type" => "text/plain"
        }

        # Encodes a `Hash(String, String)` representing cookies to a string suitable for use with the Set-Cookie header.
        # Basically the inverse of `Request.parse_cookies`. Although mostly used in encoding responses, it too can be
        # called manually.
        # Example:
        # ```
        # Coral::Response.encode_cookies { "a" => "b", "c" => "d" } # a=b;c=d
        # ```
        def self.encode_cookies(cookies : CookieMap)
            c = ""
            cookies.each do |k, v|
                c += "#{k}=#{v};"
            end
            c.rstrip ';' # Remove the trailing ";".
        end

        # Creates a new response. Should be called manually. Can take many arguments:
        #   - `body`, the response body.
        #   - `status`, the status code - should be a member of `Status`.
        #   - `headers`, the response headers.
        #   - `cookies`, the cookies to set in the client.
        # Example:
        # ```
        # Coral::Response.new "body", Status::Ok, { "Host" => "example.com" } # => <Response>
        # ```
        #
        # NOTE: while this method can be called manually, and is perfectly suitable for use, it is
        # more common to use the associated methods for MIME types.
        def initialize(body : String, status : Status = Status::Ok, headers : HeaderMap = DEFAULTHEADERS, 
                       cookies : CookieMap = CookieMap.new)
            @status = status
            @headers = DEFAULTHEADERS.merge headers
            @body = body.size != 0 ? body : "#{@status.value} #{MESSAGES[@status]}"
            @headers["Content-Length"] = body.size.to_s
            @cookies = cookies
        end

        # Creates methods for generating a response of a given MIME type. Given a category (eg., application)
        # and a name (eg., json), it generates two methods: self.{{ name }}, which given a string, will set the
        # Content-Type header to the given MIME type and the body to that string, and self.{{ name }}_file, which
        # behaves like self.{{ name }}, but which treats the string as filename and reads it instead of setting
        # the body to it.
        macro mime_constructor(category, mime)
            def self.{{ mime }}(body : String, status : Status = Status::Ok, headers : HeaderMap = DEFAULTHEADERS)
                res = Response.new body, status, headers
                res.headers["Content-Type"] = "{{ category }}/{{ mime }}"
                res
            end
            
            def self.{{ mime }}_file(filename : String, status : Status = Status::Ok, headers : HeaderMap = DEFAULTHEADERS)
                res = Response.new (File.read filename), status, headers
                res.headers["Content-Type"] = "{{ category }}/{{ mime }}"
                res
            end
        end

        # Create MIME methods for text/html, text/css, text/plain, application/javascript, and application/json.
        # NOTE: application/javascript is used rather than text/javascript because it is more modern.
        mime_constructor text, html
        mime_constructor text, css
        mime_constructor text, plain
        mime_constructor application, javascript
        mime_constructor application, json

        # Converts a response to a raw HTTP response string. Should not be called manually; invoked only in the server.
        def to_s
            @headers["Set-Cookie"] = Response.encode_cookies @cookies   # TODO: possibly allow users to set the Set-Cookie
                                                                        # themselves?
            s = "HTTP/1.0 #{@status.value}\r\n" # TODO: possibly use the HTTP version sent by the client instead of 1.0?
            @headers.each do |header, value|
                s += "#{header}: #{value}\r\n"
            end
            s + "\r\n#{@body}"
        end
    end
end