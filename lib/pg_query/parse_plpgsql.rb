require 'json'
module PgQuery
  class PlpgsqlParseError < ArgumentError
    attr_reader :location
    def initialize(message, source_file, source_line, location)
      super("#{message} (#{source_file}:#{source_line})")
      @location = location
    end
  end

  def self.parse_plpgsql(input)
    PlpgsqlParserResult.new(input, JSON.parse(_raw_parse_plpgsql(input)))
  end

  class PlpgsqlParserResult
    attr_reader :input
    attr_reader :tree

    def initialize(input, tree)
      @input = input
      @tree = tree
    end

    def walk!
      nodes = [tree.dup]
      loop do
        parent_node = nodes.shift
        if parent_node.is_a?(Array)
          parent_node.each do |node|
            yield(node)
            nodes << node
          end
        elsif parent_node.is_a?(Hash)
          parent_node.each do |k, node|
            yield(node)
            nodes << node
          end
        end
        break if nodes.empty?
      end
    end
  end
end
