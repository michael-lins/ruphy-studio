require_relative "project"
require_relative "connection"
require "fileutils"

module Ruphy
  class Resident
    def initialize(root, socket_path)
      @project = Project.new(root)
      @socket_path = socket_path
    end

    def run
      FileUtils.mkdir_p(File.dirname(@socket_path))
      # Never unlink an existing endpoint: it may belong to another running owner.
      server = UNIXServer.new(@socket_path)
      File.chmod(0o600, @socket_path)
      puts "Ruphy resident ready (#{Herb.version})"
      $stdout.flush
      loop do
        socket = server.accept
        begin
          request = Timeout.timeout(5) { socket.gets(16_385) }
          raise Error, "Request too large" if request && request.bytesize > 16_384
          message = JSON.parse(request.to_s)
          result = case message.fetch("method")
          when "state" then @project.state
          when "mutate" then @project.mutate(message.fetch("command"))
          else raise Error, "Unknown operation"
          end
          socket.puts(JSON.generate(ok: true, result: result))
        rescue StandardError => error
          status = error.is_a?(Conflict) ? 409 : 422
          socket.puts(JSON.generate(ok: false, status: status, error: error.message)) rescue nil
        ensure
          socket.close
        end
      end
    ensure
      if server
        server.close
        File.unlink(@socket_path) if File.socket?(@socket_path)
      end
    end
  end
end
