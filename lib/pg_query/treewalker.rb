module PgQuery
  class ParserResult
    # Walks the parse tree and calls the passed block for each contained node
    #
    # If you pass a block with 1 argument, you will get each node.
    # If you pass a block with 4 arguments, you will get each parent_node, parent_field, node and location.
    #
    # If sufficient for the use case, the 1 argument block approach is recommended, since it's faster.
    #
    # Location uniquely identifies a given node within the parse tree. This is a stable identifier across
    # multiple parser runs, assuming the same pg_query release and no modifications to the parse tree.
    def walk!(&block)
      if block.arity == 1
        treewalker!(@tree, &block)
      else
        treewalker_with_location!(@tree, &block)
      end
    end

    private

    def treewalker!(tree) # rubocop:disable Metrics/CyclomaticComplexity
      nodes = [tree.dup]

      loop do
        parent_node = nodes.shift

        case parent_node
        when Google::Protobuf::MessageExts
          parent_node.class.descriptor.each do |field_descriptor|
            node = field_descriptor.get(parent_node)
            next if node.nil?
            yield(node) if node.is_a?(Google::Protobuf::MessageExts) || node.is_a?(Google::Protobuf::RepeatedField)
            nodes << node
          end
        when Google::Protobuf::RepeatedField
          parent_node.each do |node|
            next if node.nil?
            yield(node) if node.is_a?(Google::Protobuf::MessageExts) || node.is_a?(Google::Protobuf::RepeatedField)
            nodes << node
          end
        end

        break if nodes.empty?
      end
    end

    def treewalker_with_location!(tree) # rubocop:disable Metrics/CyclomaticComplexity
      nodes = [[tree.dup, []]]

      loop do
        parent_node, parent_location = nodes.shift

        case parent_node
        when Google::Protobuf::MessageExts
          parent_node.class.descriptor.each do |field_descriptor|
            parent_field = field_descriptor.name
            node = parent_node[parent_field]
            next if node.nil?
            location = parent_location + [parent_field.to_sym]
            yield(parent_node, parent_field.to_sym, node, location) if node.is_a?(Google::Protobuf::MessageExts) || node.is_a?(Google::Protobuf::RepeatedField)
            nodes << [node, location]
          end
        when Google::Protobuf::RepeatedField
          parent_node.each_with_index do |node, parent_field|
            next if node.nil?
            location = parent_location + [parent_field]
            yield(parent_node, parent_field, node, location) if node.is_a?(Google::Protobuf::MessageExts) || node.is_a?(Google::Protobuf::RepeatedField)
            nodes << [node, location]
          end
        end

        break if nodes.empty?
      end
    end

    def find_tree_location(tree, searched_location)
      treewalker_with_location! tree do |parent_node, parent_field, node, location|
        next unless location == searched_location
        yield(parent_node, parent_field, node)
      end
    end
  end
end
