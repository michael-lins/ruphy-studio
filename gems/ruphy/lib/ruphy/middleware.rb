require_relative "connection"
require "cgi"
require "rack/request"

module Ruphy
  class Middleware
    PREFIX = "/__ruphy"
    ASSETS = File.expand_path("assets", __dir__)

    def initialize(app, socket_path:)
      @app = app
      @connection = Connection.new(socket_path)
    end

    def call(env)
      request = Rack::Request.new(env)
      return endpoint(request) if request.path.start_with?(PREFIX + "/")
      # Capture the revision before rendering, so an old page cannot silently edit a newer file.
      snapshot = resident("state") if request.get? && request.get_header("HTTP_ACCEPT").to_s.include?("text/html")
      status, headers, body = @app.call(env)
      return [status, headers, body] unless snapshot && status == 200 &&
        headers["content-type"].to_s.include?("text/html") && !headers["content-encoding"]
      html = +""
      begin
        body.each { |part| html << part }
      ensure
        body.close if body.respond_to?(:close)
      end
      position = html.rindex("</body>")
      if position
        data = CGI.escapeHTML(JSON.generate(snapshot))
        html.insert(position, %(<script src="#{PREFIX}/ruphino.js" data-ruphy-state="#{data}" defer></script>))
        headers = headers.dup
        %w[content-length etag content-md5].each { |key| headers.delete(key) }
      end
      [status, headers, [html]]
    end

    private

    def resident(method, command = nil)
      @connection.call(method, command)
    rescue SystemCallError, IOError, Timeout::Error, JSON::ParserError
      { "ok" => false, "status" => 503, "error" => "Ruphy resident unavailable; run mise run dev" }
    end

    def endpoint(request)
      return json(403, error: "Local development only") unless %w[127.0.0.1 ::1].include?(request.get_header("REMOTE_ADDR"))
      case [request.request_method, request.path]
      when ["GET", "#{PREFIX}/ruphino.js"]
        [200, { "content-type" => "text/javascript", "cache-control" => "no-store" }, [File.read(File.join(ASSETS, "ruphino.js"))]]
      when ["GET", "#{PREFIX}/ruphino.png"]
        [200, { "content-type" => "image/png" }, [File.binread(File.join(ASSETS, "ruphino.png"))]]
      when ["GET", "#{PREFIX}/state"]
        response = resident("state")
        json(response["ok"] ? 200 : response.fetch("status", 422), response)
      when ["POST", "#{PREFIX}/mutations"]
        return json(403, error: "Same-origin JSON required") unless request.get_header("HTTP_ORIGIN") == request.base_url && request.media_type == "application/json"
        raw = request.body.read(16_385)
        return json(413, error: "Request too large") if raw.bytesize > 16_384
        response = resident("mutate", JSON.parse(raw))
        json(response["ok"] ? 200 : response.fetch("status", 422), response)
      else
        json(404, error: "Not found")
      end
    rescue JSON::ParserError
      json(400, error: "Invalid JSON")
    end

    def json(status, payload)
      [status, { "content-type" => "application/json", "cache-control" => "no-store" }, [JSON.generate(payload)]]
    end
  end
end
