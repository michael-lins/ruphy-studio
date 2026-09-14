require "bundler/setup"
require "rails"
require "action_controller/railtie"
Bundler.require(*Rails.groups)

module CustomerCanvas
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "ruphy-local-toy-application-only-" * 4
    config.hosts = ["localhost", "127.0.0.1"]
    config.action_controller.perform_caching = false
    config.action_view.cache_template_loading = false
    config.logger = Logger.new($stdout)
  end
end
