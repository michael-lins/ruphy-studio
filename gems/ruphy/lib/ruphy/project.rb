require "herb"
require "digest"
require "cgi"
require "tempfile"
require "thread"

module Ruphy
  class Error < StandardError; end
  class Conflict < Error; end

  # One view, two literal HTML inputs, one operation. No Rails dependency.
  class Project
    VIEW = "app/views/customers/new.html.erb"
    TARGETS = %w[customer_name customer_email].freeze

    def initialize(root)
      @root = File.realpath(root)
      @path = File.join(@root, VIEW)
      @mutex = Mutex.new
      @last_change = nil
    end

    def state
      @mutex.synchronize do
        source = read_source
        tree = parse(source)
        fields = TARGETS.map do |id|
          value = target_value(tree, id)
          { id: id, placeholder: CGI.unescapeHTML(inner_source(source, value)) }
        end
        { revision: revision(source), view: VIEW, fields: fields, last_change: @last_change }
      end
    end

    def mutate(command)
      @mutex.synchronize do
        raise Error, "Unsupported mutation" unless command.is_a?(Hash) &&
          command.keys.sort == %w[operation revision target value] &&
          command["operation"] == "set_placeholder"
        id, replacement = command.values_at("target", "value")
        raise Error, "Unsupported target" unless TARGETS.include?(id)
        raise Error, "Use up to 200 printable characters" unless replacement.is_a?(String) &&
          replacement.valid_encoding? && replacement.length <= 200 &&
          replacement.codepoints.none? { |c| c < 32 || c == 127 }

        original = read_source
        raise Conflict, "View changed; reload before editing" unless command["revision"] == revision(original)
        tree = parse(original)
        value = target_value(tree, id)
        from = offset(original, value.open_quote.location.end)
        to = offset(original, value.close_quote.location.start)
        escaped = CGI.escapeHTML(replacement)
        candidate = original[0...from] + escaped + original[to..]
        verified = target_value(parse(candidate), id)
        raise Error, "Mutation postcondition failed" unless CGI.unescapeHTML(inner_source(candidate, verified)) == replacement

        diff = Herb.diff(original, candidate)
        operations = diff.operations.map { |op| { type: op.type.to_s, path: op.path } }
        unless diff.identical? || operations.map { |op| op[:type] } == ["attribute_value_changed"]
          raise Error, "Unexpected structural diff"
        end
        raise Conflict, "View changed during validation" unless read_source == original
        write_source(candidate, original) unless original == candidate
        @last_change = {
          operation: "set_placeholder", target: id,
          before: revision(original), after: revision(candidate),
          diff: { identical: diff.identical?, operations: operations }
        }
        { revision: revision(candidate), reload: original != candidate, change: @last_change }
      end
    end

    private

    def read_source
      raise Error, "View must be a regular file inside the project" unless
        File.file?(@path) && File.realpath(@path) == @path
      source = File.binread(@path).force_encoding(Encoding::UTF_8)
      raise Error, "View must be valid UTF-8 without NUL" unless source.valid_encoding? && !source.include?("\0")
      source
    end

    def parse(source)
      result = Herb.parse(source, track_whitespace: true)
      raise Error, "Herb rejected the view: #{result.errors.map(&:message).join('; ')}" unless result.errors.empty?
      result.value
    end

    def walk(node, ancestors = [], &block)
      yield node, ancestors
      node.child_nodes.compact.each { |child| walk(child, ancestors + [node], &block) }
    end

    def attributes(element, name)
      element.open_tag.children.select do |node|
        node.is_a?(Herb::AST::HTMLAttributeNode) &&
          node.name.children.all? { |part| part.is_a?(Herb::AST::LiteralNode) } &&
          node.name.children.map(&:content).join == name
      end
    end

    def target_value(tree, id)
      matches = []
      walk(tree) do |node, ancestors|
        next unless node.is_a?(Herb::AST::HTMLElementNode)
        ids = attributes(node, "id")
        next unless ids.any? { |attr| attr.value && attr.value.children.all? { |part| part.is_a?(Herb::AST::LiteralNode) } && CGI.unescapeHTML(attr.value.children.map(&:content).join) == id }
        raise Error, "Ambiguous id attribute" unless ids.one?
        raise Error, "Only literal HTML inputs are supported" unless node.tag_name.value == "input" &&
          ancestors.none? { |ancestor| ancestor.class.name.split("::").last.start_with?("ERB") }
        matches << node
      end
      raise Error, "Target must identify exactly one input" unless matches.one?
      attrs = attributes(matches.first, "placeholder")
      raise Error, "Target needs one literal quoted placeholder" unless attrs.one?
      value = attrs.first.value
      raise Error, "Target needs one literal quoted placeholder" unless value && value.open_quote && value.close_quote &&
        value.children.all? { |part| part.is_a?(Herb::AST::LiteralNode) }
      value
    end

    # Herb columns count characters, not bytes or JavaScript UTF-16 units.
    def offset(source, position)
      lines = source.lines
      prefix = lines.take(position.line - 1).sum(&:length)
      prefix + position.column
    end

    def inner_source(source, value)
      source[offset(source, value.open_quote.location.end)...offset(source, value.close_quote.location.start)]
    end

    def revision(source)
      Digest::SHA256.hexdigest(source)
    end

    def write_source(candidate, original)
      Tempfile.create([".ruphy-", ".erb"], File.dirname(@path)) do |file|
        file.binmode
        file.write(candidate)
        file.flush
        file.fsync
        file.chmod(File.stat(@path).mode & 0o777)
        raise Conflict, "View changed before write" unless read_source == original
        File.rename(file.path, @path)
      end
    end
  end
end
