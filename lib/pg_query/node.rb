module PgQuery
  # Patch the auto-generated generic node type with additional convenience functions
  class Node
    def self.inner_class_to_name(klass)
      @inner_class_to_name ||= descriptor.lookup_oneof('node').to_h { |f| [f.subtype.msgclass, f.name.to_sym] }
      @inner_class_to_name[klass]
    end

    def inner
      self[node.to_s]
    end

    def inner=(submsg)
      name = self.class.inner_class_to_name(submsg.class)
      public_send("#{name}=", submsg)
    end

    def inspect
      node ? format('<PgQuery::Node: %s: %s>', node, inner.inspect) : '<PgQuery::Node>'
    end

    # Make it easier to initialize nodes from a given node child object
    def self.from(node_field_val)
      PgQuery::Node.new(inner_class_to_name(node_field_val.class) => node_field_val)
    end

    # Make it easier to initialize value nodes
    def self.from_string(sval)
      PgQuery::Node.new(string: PgQuery::String.new(sval: sval))
    end

    def self.from_integer(ival)
      PgQuery::Node.new(integer: PgQuery::Integer.new(ival: ival))
    end
  end
end
