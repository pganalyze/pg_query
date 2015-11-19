class PgQuery
  # Reconstruct all of the parsed queries into their original form
  def deparse(tree = @parsetree)
    tree.map do |item|
      Deparse.from(item)
    end.join('; ')
  end

  module Deparse
    extend self

    # Deprecated
    def deparse_item(item, context = nil)
      from(item, context)
    end

    # Given one element of the PgQuery#parsetree reconstruct it back into the
    # original query.
    def from(item, context = nil)
      return if item.nil?
      return item if item.is_a?(Fixnum) || item.is_a?(String)

      type = item.keys[0]
      node = item.values[0]

      deparser = type_to_deparser(type) || fail(format("Can't deparse: %s: %s", type, node.inspect))
      deparser.call(node, context)
    end
  end
end

Dir[File.dirname(__FILE__) + '/deparse/*.rb'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/deparse_helper/*.rb'].each { |file| require file }
