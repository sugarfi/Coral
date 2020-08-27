require "./status"

# Module for representing and parsing requests. Defines several classes, including the Request class,
# which is passed as a parameter to all handlers.
module Coral
    private alias HeaderMap = Hash(String, String)
    private alias CookieMap = Hash(String, String)
    private alias BodyType = JSON::Any | Hash(String, String) | String | Nil
    private alias FileMap = Hash(String, MultipartFile)

    # Represents a file in a multipart request. Stores filename, body, and, if given, the MIME type
    # of a file.
    class MultipartFile
        getter filename : String, body : String, type : String?
        def initialize(filename : String, body : String, type : String?)
            @filename = filename
            @body = body
            @type = type
        end
    end

    # Base request class. Passed as a parameter to all handlers; should not be created manually. It defines several
    # properties for convenience, and also several class methods used in the creation of requests.
    class Request
        getter method : String, path : String, headers : HeaderMap, cookies : CookieMap = CookieMap.new, files : FileMap
        property body
        
        # Parses a `Cookie` header into a `Hash(String, String)` representing all passed cookies. Works by splitting
        # the header on ";" characters, then splitting those on "=" characters to generate key value pairs. Mainly used
        # for parsing cookies when a request object is created, but can be invoked manually.
        # Example:
        # ```
        # Coral::Request.parse_cookies "a=b;c=d" # { "a" => "b", "c" => "d" }
        # ```
        # 
        # NOTE: this function assumes any passed input is valid, and will throw an exception if it is not. If you are
        # calling it manually, be sure to validate input first.
        def self.parse_cookies(header : String)
            c = CookieMap.new
            (header.split ";").each do |cookie|
                if cookie.size > 0
                    k, v = cookie.split("=")
                    c[k] = v
                end
            end
            c
        end

        # Parses a mutlipart form body (ie., MIME type `multipart/form-data`) into a `Hash(String, Coral::MultipartFile)`
        # mapping the name fields of inputs to `Coral::MultipartFile` objects. This as well is used mainly in creating
        # a request, but it can also be called manually. Takes as input the multipart data, and its boundary string.
        # Like #parse_cookies, it assumes the input is valid, so be sure to validate it yourself if you call this manually.
        #
        # TODO: since this is mainly used for body parsing, it could potentially be migrated to a subclass of
        # `Coral::BodyParser`.
        def self.parse_multipart(data : String, boundary : String)
            files = FileMap.new
            ((data.as String).split boundary)[1..].each do |item|
                if item != "" && item != "--\r\n"   # the `--\r\n` is needed because by default mutlipart bodies are
                                                    # terminated by the original boundary with two extra leading hypens,
                                                    # to when splitting by this boundary these two hypens remain.
                    headers = (item.split "\r\n")[..3]
                    headers = headers[1..]
                    body = item[((headers.map &.size).sum + 8)..][..-2] # Strips off the headers and some other garbage.
                    if (headers[0].includes? "filename") && headers[0].includes? "name" # TODO: fix the redundancy with
                                                                                        # "filename" and "name".
                        filename = (/filename *= *"([^"]*)"/.match headers[0]).try &.[1]
                        name = (/name *= *"([^"]*)"/.match headers[0]).try &.[1]    # NOTE: Not sure if spaces are allowed 
                                                                                    # around the "=", but I'll leave them
                                                                                    # just in case.
                        type = nil
                        if headers.size == 2
                            type = (headers[1].split ' ')[1]
                        end
                        files[name.as String] = MultipartFile.new(filename.as String, body[..-4], type) # The [..-4] is needed
                                                                                                        # because of some weird
                                                                                                        # trailing whitespace.
                    end
                end
            end
            files
        end

        # Creates a new request. Should never be called manually.
        def initialize(method : String, path : String, headers : HeaderMap, body : BodyType)
            @method = method
            @path = path
            @headers = headers
            @body = body
            @files = FileMap.new
            @cookies = Request.parse_cookies @headers.fetch "Cookie", "" # Parse cookies.

            if /^multipart\/form-data; *boundary *= *.*$/ =~ @headers.fetch "Content-Type", ""  # Here, we check if the
                                                                                                # `Content-Type` header is a
                                                                                                # valid multipart header, ie.
                                                                                                # contains the boundary and the
                                                                                                # multipart MIME type. If it
                                                                                                # is, we extract the boundary
                                                                                                # and remove everything but
                                                                                                # the MIME type, and then parse
                                                                                                # the multipart body.
                boundary = 
                    (/^multipart\/form-data; *boundary *= *(.*)$/.match @headers["Content-Type"]).try &.[1]
                @headers["Content-Type"] = "multipart/form-data"
                @files = Request.parse_multipart @body, boundary
            end
        end

        # Given the raw string body of an HTTP request, creates a request. Uses simple regex to parse the HTTP version number,
        # headers, and body. This method can be called manually, but usually is handled by the server.
        # Example:
        # ```
        # Coral::Request.from "GET / HTTP/1.1\nHost: http://example.com\n" # => <Request>
        # ```
        # Like `#parse_cookies` and `#parse_multipart`, this method assumes validity of input, and so you should take care
        # when calling it yourself.
        #
        # NOTE: this method uses "\n" as a seperator, rather than the default "\r\n". This is because the server passes it
        # input in that format, rather than the default. If calling manually, keep this in mind.
        def self.from(body : String)
            body = body.split "\n"
            unless /^[A-Z]+ *(\/[\w?&=.]*)+ *HTTP\/[10]\.\d$/ =~ (top = body[0])
                return Status::BadRequest
            end
            body = body[1..] # FIXME: should probably use `body#shift` here.
            method, path, _ = top.split ' '

            headers = HeaderMap.new
            while /^[A-z-]+ *: *.+$/ =~ (line = body[0]) # NOTE: not sure if spaces are allowed around the ":"; see above.
                body = body[1..]
                header, value = (line.sub ' ', "").split ":"
                headers[header] = value
            end
            
            Request.new method, path, headers, body.join "\n"   # TODO: if `body` contained multiple newlines in a row, they
                                                                # will be lost here. It might be good to find a better way to
                                                                # split, so that this doesn't come up.
        end
    end
end