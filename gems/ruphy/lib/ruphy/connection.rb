require "socket"
require "json"
require "timeout"

module Ruphy
  class Connection
    def initialize(socket_path)
      @socket_path = socket_path
    end

    def call(method, command = nil)
      Timeout.timeout(5) do
        UNIXSocket.open(@socket_path) do |socket|
          socket.puts(JSON.generate(method: method, command: command))
          response = socket.gets
          raise IOError, "Resident process closed the connection" unless response
          JSON.parse(response)
        end
      end
    end
  end
end
