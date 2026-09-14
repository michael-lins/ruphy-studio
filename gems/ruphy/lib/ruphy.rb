require "rails/railtie"
require_relative "ruphy/middleware"

module Ruphy
  class Railtie < Rails::Railtie
    initializer "ruphy.development_canvas" do |app|
      if Rails.env.development?
        socket = ENV.fetch("RUPHY_SOCKET") { app.root.join("tmp/ruphy.sock").to_s }
        app.middleware.use Ruphy::Middleware, socket_path: socket
      end
    end
  end
end
