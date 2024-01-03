module PgQuery
  class ParserResult
    # Walks the parse tree and calls the passed block for each contained node
    #
    # If you pass a block with 1 argument, you will get each node.
    # If you pass a block with 4 arguments, you will get each parent_node, parent_field, node and location.
    #
    # Location uniquely identifies a given node within the parse tree. This is a stable identifier across
    # multiple parser runs, assuming the same pg_query release and no modifications to the parse tree.
    def walk!(&block)
      if block.arity == 1
        treewalker!(@tree) do |_, _, node, _|
          yield(node)
        end
      else
        treewalker!(@tree) do |parent_node, parent_field, node, location|
          yield(parent_node, parent_field, node, location)
        end
      end
    end

    private

    def treewalker!(tree) # rubocop:disable Metrics/CyclomaticComplexity
      nodes = [[tree.dup, []]]

      loop do
        parent_node, parent_location = nodes.shift

        case parent_node
        when Google::Protobuf::MessageExts
          parent_node.to_h.keys.each do |parent_field|
            node = parent_node[parent_field.to_s]
            next if node.nil?
            location = parent_location + [parent_field]
            yield(parent_node, parent_field, node, location) if node.is_a?(Google::Protobuf::MessageExts) || node.is_a?(Google::Protobuf::RepeatedField)

            nodes << [node, location] unless node.nil?
          end
        when Google::Protobuf::RepeatedField
          parent_node.each_with_index do |node, parent_field|
            next if node.nil?
            location = parent_location + [parent_field]
            yield(parent_node, parent_field, node, location) if node.is_a?(Google::Protobuf::MessageExts) || node.is_a?(Google::Protobuf::RepeatedField)

            nodes << [node, location] unless node.nil?
          end
        end

        break if nodes.empty?
      end
    end

    def find_tree_location(tree, searched_location)
      treewalker! tree do |parent_node, parent_field, node, location|
        next unless location == searched_location
        yield(parent_node, parent_field, node)
      end
    end
  end
end
