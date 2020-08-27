require "socket"
require "./bodyparser"

# The server module. Defines a server class, which interfaces with all other classes to provide the actual server.
module Coral
    class Server
        private alias HandlerMap = Hash(String, Hash(String, Proc(Request, Response)))
        private alias ParserMap = Hash(String, BodyParser)
        private alias State = Hash(String, String | Int32)

        getter port : Int32
        getter state : State

        handlers : HandlerMap
        parsers : ParserMap
        pending : Channel(Tuple(TCPSocket, Request))

        # Creates a server. This is meant to be called manually. Unlike response, there are no alternate constructors. It
        # takes two parameters: the port and optionally capacity. Capacity is the size of the channel for requests - a
        # small value will cause blocking if too many requests occur at once. The default is 32.
        # Example:
        # ```
        # Coral::Server.new 3000 # => <Server>
        # ```
        def initialize(port : Int32, cap : Int32 = 32)
            @port = port
            @handlers = HandlerMap.new
            @parsers = { # Default MIME type parsers: JSON and URL encoded
                "application/json" => JSONBodyParser,
                "application/x-www-form-urlencoded" => URLBodyParser
            }
            @pending = Channel(Tuple(TCPSocket, Request)).new cap
            @state = State.new
        end

        # Adds a custom parser to the server. Takes as input the MIME type this parser is meant to parse, and a subclass
        # of `BodyParser`, implementing `self.parse`. This can be used to overwrite old parsers.
        # Example:
        # ```
        # server.set_parser "application/gzip", MyGzipParser
        # ```
        def set_parser(content_type : String, parser : BodyParser)
            @parsers[content_type] = parse
        end

        # Generates a handler method for a specific method. Given a request method, creates a method {{ method }} that,
        # given a path and a block or proc, associates that method and that path with that proc.
        #
        # NOTE: request methods will always be uppercased.
        private macro request_creator(method)
            # Creates handlers for requests with the "{{ method }}" method. Given a path and a block or proc,
            # associates a {{ method }} request to that path with the given block or proc.
            # Example:
            # ```
            # server.{{ method }} "/" do |req|
            #   ...
            # end
            # ```
            def {{ method }}(path : String, &handler : Proc(Request, Response))
                @handlers = { "{{ method }}".upcase => Hash(String, Proc(Request, Response)).new }.merge @handlers
                @handlers["{{ method }}".upcase][path] = handler
            end
        end

        # Defines request methods for all major HTTP methods.
        #
        # FIXME: does not include RFC-TEA.


        request_creator get
        request_creator post
        request_creator patch
        request_creator put
        request_creator delete
        request_creator options
        request_creator head

        # Starts the server. Takes no parameters.
        # Example:
        # ```
        # server.start
        # ```
        def start
            server = TCPServer.new "0.0.0.0", @port
            puts "\x1b[0;33mListening on \x1b[0;32m0.0.0.0:\x1b[0;34m#{@port}\x1b[0;0m..."  # TODO: add an option to disable
                                                                                            # logging.
            
            spawn do # Spawns the handler fiber.
                loop do
                    unless (val = @pending.receive?) == nil
                        client, req = val.as Tuple(TCPSocket, Request)
                        puts "\x1b[0;33m#{req.method} \x1b[0;34m#{req.path}"

                        if !@handlers.fetch req.method, false # TODO: allow custom error handlers for these cases.
                            res = Response.new "", Status::NotAllowed
                        elsif !@handlers[req.method].fetch req.path, false
                            res = Response.new "", Status::NotFound
                        else
                            res = @handlers[req.method][req.path].call(req)
                        end
                        client.puts res.to_s

                        if res.status.value >= 400 # TODO: better status coloring.
                            puts "↳\x1b[0;31m#{res.status.value} \x1b[0;34m#{MESSAGES[res.status]}"
                        elsif res.status.value >= 200
                            puts "↳\x1b[0;32m#{res.status.value} \x1b[0;34m#{MESSAGES[res.status]}"
                        else
                            puts "↳\x1b[0;33m#{res.status.value} \x1b[0;34m#{MESSAGES[res.status]}"
                        end
                        client.close
                    end
                end
            end

            # Start the socket loop.
            loop do
                client = server.accept?.as TCPSocket
                data = ""
                while (line = client.read_line) != "" # We read data line by line, rather than byte by byte.
                    data += line + "\n" # NOTE: because we concatenate with "\n", all "\r"s will be dropped.
                end
                req = Request.from data # NOTE: we create a first request here, containing only headers. This is so
                                        # that when getting the body we can access Content-Length.

                if req.is_a? Status # If `req` is a status the parsing failed.
                    req = req.as Status
                    client.puts "HTTP/1.0 #{req} #{MESSAGES[req]}"
                    client.puts "#{req} #{MESSAGES[req]}"
                    client.close
                else
                    data2 = ""  # NOTE: here we repeat almost the same process as above, but we use Content-Length to read
                                # the right number of bytes.
                    if /^multipart\/form-data; *boundary *= *.*$/ =~ req.headers.fetch "Content-Type", ""
                        boundary =  # FIXME: this seperate parsing method for multipart forms is a relic from a testing
                                    # error, but it works so I'll leave it around for now.
                            (/^multipart\/form-data; *boundary *= *(.*)$/.match req.headers["Content-Type"]).try &.[1]
                        while (line = client.read_line) != "--#{boundary}--"
                            data2 += line + "\n"
                        end
                    else
                        data2 = Bytes.new (req.headers.fetch "Content-Length", "0").to_i
                        client.read data2
                        data2 = String.new data2
                    end
                    req = Request.from data + data2

                    if req.is_a? Status # See above.
                        req = req.as Status
                        client.puts "HTTP/1.0 #{req} #{MESSAGES[req]}"
                        client.puts "#{req} #{MESSAGES[req]}"
                        client.close
                    else
                        req = req.as Request

                        if @parsers[req.headers["Content-Type"]?]? && req.body.is_a? String # Here we parse the request body
                                                                                            # if it has a known MIME type.
                            req.body = @parsers[req.headers["Content-Type"]].parse(req.body.as String)
                        end

                        @pending.send({ client, req })
                    end
                end            
            end
        end
    end
end