module PgQuery
  # Patch the auto-generated generic node type with additional convenience functions
  class Node
    def inspect
      node ? format('<PgQuery::Node: %s: %s>', node, public_send(node).inspect) : '<PgQuery::Node>'
    end

    # Make it easier to initialize nodes from a given node child object
    def self.from(node_field_val)
      PgQuery::Node.new(node_field_name(node_field_val) => node_field_val)
    end

    # Make it easier to initialize value nodes
    def self.from_string(str)
      PgQuery::Node.new(string: PgQuery::String.new(str: str))
    end
    def self.from_integer(ival)
      PgQuery::Node.new(integer: PgQuery::Integer.new(ival: ival))
    end

    private

    # This needs to match libpg_query naming for the Node message field names
    # (see "underscore" method in libpg_query's scripts/generate_protobuf_and_funcs.rb)
    def self.node_field_name(node_field_val)
      camel_cased_word = node_field_val.class.name.split('::').last
      return camel_cased_word unless /[A-Z-]|::/.match?(camel_cased_word)
      word = camel_cased_word.to_s.gsub("::", "/")
      word.gsub!(/^([A-Z\d])([A-Z][a-z])/, '\1__\2')
      word.gsub!(/([A-Z\d]+[a-z]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end
end
