require "bundler/setup"
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "rack/mock"
require "ruphy/project"
require "ruphy/middleware"
require "ruphy/resident"
require "open3"
require "rbconfig"

class ProjectTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("ruphy-test")
    @path = File.join(@root, Ruphy::Project::VIEW)
    FileUtils.mkdir_p(File.dirname(@path))
    @source = "<form>Olá 🌿\r\n  <input id=\"customer_name\" placeholder='Full name'>\r\n  <input id=\"customer_email\" placeholder=\"Email\">\r\n</form>\r\n"
    File.binwrite(@path, @source)
    @project = Ruphy::Project.new(@root)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def command(value = "Nome completo", target = "customer_name")
    { "operation" => "set_placeholder", "target" => target,
      "value" => value, "revision" => Digest::SHA256.hexdigest(File.binread(@path)) }
  end

  def test_real_herb_diff_and_exact_preservation
    result = @project.mutate(command)
    assert_equal @source.sub("Full name", "Nome completo"), File.binread(@path).force_encoding("UTF-8")
    assert_equal ["attribute_value_changed"], result[:change][:diff][:operations].map { |op| op[:type] }
    assert result[:reload]
    assert Herb.parse(File.read(@path)).errors.empty?
  end

  def test_edit_targets_the_configured_partial_and_preserves_its_caller
    assert_equal "app/views/customers/_form.html.erb", Ruphy::Project::VIEW
    caller_path = File.join(@root, "app/views/customers/new.html.erb")
    caller_source = '<main><%= render "form" %></main>'
    File.write(caller_path, caller_source)
    @project.mutate(command)
    assert_equal caller_source, File.read(caller_path)
    assert_equal "app/views/customers/_form.html.erb", @project.state[:view]
    assert_includes File.read(@path), "Nome completo"
  end

  def test_unicode_on_same_line_and_markup_is_literal
    File.write(@path, @source.delete("\r\n"))
    before = File.read(@path)
    text = %q{O'Neil "🌿" & <%= dangerous %>}
    @project.mutate(command(text))
    assert_equal before.sub("Full name", CGI.escapeHTML(text)), File.read(@path)
    assert_equal text, @project.state[:fields].first[:placeholder]
  end

  def test_stale_revision_does_not_overwrite_external_edit
    edit = command
    File.write(@path, @source + "<!-- external -->")
    assert_raises(Ruphy::Conflict) { @project.mutate(edit) }
    assert_equal @source + "<!-- external -->", File.read(@path)
  end

  def test_duplicate_target_rejected
    File.write(@path, @source + '<input id="customer_name" placeholder="Other">')
    before = File.read(@path)
    assert_raises(Ruphy::Error) { @project.mutate(command) }
    assert_equal before, File.read(@path)
    File.write(@path, @source + '<input id="customer&#95;name" placeholder="Other">')
    assert_raises(Ruphy::Error) { @project.mutate(command) }
  end

  def test_dynamic_placeholder_and_conditional_target_rejected
    File.write(@path, @source.sub("Full name", "<%= @name %>"))
    assert_raises(Ruphy::Error) { @project.mutate(command) }
    File.write(@path, "<% if true %>#{@source}<% end %>")
    assert_raises(Ruphy::Error) { @project.mutate(command) }
  end

  def test_invalid_original_rejected_without_write
    File.write(@path, @source + "<div>")
    before = File.read(@path)
    assert_raises(Ruphy::Error) { @project.mutate(command) }
    assert_equal before, File.read(@path)
  end

  def test_noop_and_empty_value
    result = @project.mutate(command("Full name"))
    refute result[:reload]
    assert result[:change][:diff][:identical]
    @project.mutate(command(""))
    assert_equal "", @project.state[:fields].first[:placeholder]
  end

  def test_rejects_paths_unknown_operations_and_control_characters
    assert_raises(Ruphy::Error) { @project.mutate(command("x", "../../Gemfile")) }
    assert_raises(Ruphy::Error) { @project.mutate(command.merge("operation" => "write_file")) }
    assert_raises(Ruphy::Error) { @project.mutate(command("a\0b")) }
    assert_equal @source, File.read(@path)
  end

  def test_external_change_during_validation_is_rejected
    @project.define_singleton_method(:parse) do |source|
      result = super(source)
      @parsed_count = (@parsed_count || 0) + 1
      File.write(@path, source + "<!-- external -->") if @parsed_count == 2
      result
    end
    assert_raises(Ruphy::Conflict) { @project.mutate(command) }
    assert File.read(@path).end_with?("<!-- external -->")
  end

  def test_symlink_is_rejected
    other = File.join(@root, "other.erb")
    File.rename(@path, other)
    File.symlink(other, @path)
    assert_raises(Ruphy::Error) { @project.mutate(command) }
    assert_equal @source, File.read(other)
  end

  def test_unquoted_and_missing_placeholders_are_rejected
    File.write(@path, @source.sub("placeholder='Full name'", "placeholder=Name"))
    assert_raises(Ruphy::Error) { @project.mutate(command) }
    File.write(@path, @source.sub("placeholder='Full name'", ""))
    assert_raises(Ruphy::Error) { @project.mutate(command) }
  end

  def undo_command
    state = @project.state
    { "operation" => "undo", "revision" => state[:revision],
      "change_id" => state.fetch(:undo).fetch(:change_id) }
  end

  def test_undo_restores_exact_source_with_reverse_herb_diff
    File.chmod(0o640, @path)
    @project.mutate(command(%q{O'Neil & 🌿}))
    edit = undo_command
    result = @project.mutate(edit)
    assert_equal @source.b, File.binread(@path)
    assert_equal 0o640, File.stat(@path).mode & 0o777
    assert_equal "undo", result[:change][:operation]
    assert_equal ["attribute_value_changed"], result[:change][:diff][:operations].map { |op| op[:type] }
    assert result[:reload]
    assert_nil @project.state[:undo]
    assert_raises(Ruphy::Error) { @project.mutate(edit) }
  end

  def test_undo_rejects_external_edits_even_with_a_fresh_revision
    @project.mutate(command)
    edit = undo_command
    external = File.read(@path) + "<!-- keep external -->"
    File.write(@path, external)
    assert_nil @project.state[:undo]
    assert_raises(Ruphy::Conflict) { @project.mutate(edit) }
    edit["revision"] = Digest::SHA256.hexdigest(external)
    assert_raises(Ruphy::Conflict) { @project.mutate(edit) }
    assert_equal external, File.read(@path)
  end

  def test_only_latest_edit_is_undoable_and_old_tokens_are_rejected
    @project.mutate(command("First"))
    first_source = File.binread(@path)
    old = undo_command
    @project.mutate(command("Second"))
    latest = undo_command
    assert_raises(Ruphy::Conflict) { @project.mutate(old.merge("revision" => latest["revision"])) }
    @project.mutate(latest)
    assert_equal first_source, File.binread(@path)
    assert_nil @project.state[:undo]
  end

  def test_noop_and_rejected_edits_preserve_undo_and_restart_clears_it
    assert_nil @project.state[:undo]
    @project.mutate(command("First"))
    previous = @project.state[:undo]
    @project.mutate(command("First"))
    assert_equal previous, @project.state[:undo]
    assert_raises(Ruphy::Error) { @project.mutate(command("\0")) }
    assert_equal previous, @project.state[:undo]
    assert_nil Ruphy::Project.new(@root).state[:undo]
    @project.mutate(undo_command)
    assert_equal @source.b, File.binread(@path)
  end

  def test_undo_rechecks_source_after_validation
    @project.mutate(command)
    edit = undo_command
    @project.define_singleton_method(:parse) do |source|
      result = super(source)
      File.write(@path, source + "<!-- intervening -->")
      result
    end
    assert_raises(Ruphy::Conflict) { @project.mutate(edit) }
    assert File.read(@path).end_with?("<!-- intervening -->")
  end
end

class ResidentTest < Minitest::Test
  def test_separate_resident_serializes_competing_revisions
    root = Dir.mktmpdir("ruphy-rpc")
    path = File.join(root, Ruphy::Project::VIEW)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, '<form><input id="customer_name" placeholder="Name"><input id="customer_email" placeholder="Email"></form>')
    socket = File.join(root, "resident.sock")
    pid = fork do
      trap("TERM") { exit! }
      $stdout.reopen(File::NULL, "w")
      Ruphy::Resident.new(root, socket).run
    end
    Timeout.timeout(5) { sleep 0.01 until File.socket?(socket) }
    client = Ruphy::Connection.new(socket)
    snapshot = client.call("state")
    assert snapshot["ok"]
    command = { "operation" => "set_placeholder", "target" => "customer_name", "value" => "New name", "revision" => snapshot["result"]["revision"] }
    results = 2.times.map { Thread.new { client.call("mutate", command) } }.map(&:value)
    assert_equal 1, results.count { |result| result["ok"] }
    assert_equal 1, results.count { |result| result["status"] == 409 }
    assert_includes File.read(path), 'placeholder="New name"'
    assert_equal "attribute_value_changed", client.call("state")["result"]["last_change"]["diff"]["operations"].first["type"]
    state = client.call("state")["result"]
    undo = { "operation" => "undo", "revision" => state["revision"], "change_id" => state["undo"]["change_id"] }
    result = client.call("mutate", undo)
    assert result["ok"]
    assert_equal "undo", result["result"]["change"]["operation"]
    assert_includes File.read(path), 'placeholder="Name"'
    refute client.call("mutate", undo)["ok"]
  ensure
    if pid
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
    FileUtils.remove_entry(root) if root
  end
end

class EnvironmentTest < Minitest::Test
  def test_customer_page_renders_the_real_form_partial
    script = <<~RUBY
      require_relative "examples/customer/config/environment"
      html = CustomersController.render(:new, assigns: { heading: "Partial proof" })
      abort "Partial was not rendered" unless html.include?('id="customer_name"') && html.include?('id="customer_email"')
      puts "rendered"
    RUBY
    assert_includes File.read("examples/customer/app/views/customers/new.html.erb"), '<%= render "form" %>'
    output, errors, status = Open3.capture3({ "RAILS_ENV" => "test" }, RbConfig.ruby, "-e", script)
    assert status.success?, errors
    assert_equal "rendered", output.lines.last.strip
  end

  def test_railtie_only_installs_in_development
    %w[development test production].each do |environment|
      script = 'require_relative "examples/customer/config/environment"; puts Rails.application.middleware.any? { |m| m.klass.name == "Ruphy::Middleware" }'
      output, errors, status = Open3.capture3({ "RAILS_ENV" => environment }, RbConfig.ruby, "-e", script)
      assert status.success?, errors
      assert_equal (environment == "development").to_s, output.strip
    end
  end
end

class MiddlewareTest < Minitest::Test
  def setup
    @middleware = Ruphy::Middleware.new(->(_env) { [200, { "content-type" => "text/html", "etag" => "old", "content-length" => "20" }, ["<body>Rails</body>"]] }, socket_path: "/nonexistent-ruphy.sock")
    @request = Rack::MockRequest.new(@middleware)
  end

  def test_injects_into_response_without_touching_erb_when_resident_is_down
    response = @request.get("/", "HTTP_ACCEPT" => "text/html")
    assert_includes response.body, "/__ruphy/ruphino.js"
    assert_includes response.body, "resident unavailable"
    assert_nil response["etag"]
    assert_nil response["content-length"]
  end

  def test_non_html_requests_are_unchanged
    assert_equal "<body>Rails</body>", @request.get("/").body
  end

  def test_cross_origin_and_nonlocal_mutations_rejected
    assert_equal 403, @request.post("/__ruphy/mutations", "REMOTE_ADDR" => "127.0.0.1", "HTTP_ORIGIN" => "https://example.com", "CONTENT_TYPE" => "application/json", input: "{}").status
    assert_equal 403, @request.get("/__ruphy/state", "REMOTE_ADDR" => "192.0.2.1").status
  end

  def test_malformed_json_rejected
    response = @request.post("http://localhost/__ruphy/mutations", "REMOTE_ADDR" => "127.0.0.1", "HTTP_ORIGIN" => "http://localhost", "CONTENT_TYPE" => "application/json", input: "{")
    assert_equal 400, response.status
  end
end
