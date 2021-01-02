module PgQuery
  A_TRUNCATED = 'A_Truncated'.freeze

  class ParseResult
    PossibleTruncation = Struct.new(:location, :node_type, :length, :is_array)

    # Truncates the query string to be below the specified length, first trying to
    # omit less important parts of the query, and only then cutting off the end.
    def truncate(max_length)
      output = deparse(@tree)

      # Early exit if we're already below the max length
      return output if output.size <= max_length

      truncations = find_possible_truncations

      # Truncate the deepest possible truncation that is the longest first
      truncations.sort_by! { |t| [-t.location.size, -t.length] }

      tree = deep_dup(@tree)
      truncations.each do |truncation|
        next if truncation.length < 3

        find_tree_location(tree, truncation.location) do |expr, k|
          expr[k] = { A_TRUNCATED => nil }
          expr[k] = [expr[k]] if truncation.is_array
        end

        output = deparse(tree)
        return output if output.size <= max_length
      end

      # We couldn't do a proper smart truncation, so we need a hard cut-off
      output[0..max_length - 4] + '...'
    end

    private

    def find_possible_truncations
      truncations = []

      treewalker! @tree do |_expr, k, v, location|
        case k
        when TARGET_LIST_FIELD
          length = deparse([{ SELECT_STMT => { k => v } }]).size - 7 # 'SELECT '.size

          truncations << PossibleTruncation.new(location, TARGET_LIST_FIELD, length, true)
        when 'whereClause'
          length = deparse([{ SELECT_STMT => { k => v } }]).size

          truncations << PossibleTruncation.new(location, 'whereClause', length, false)
        when 'ctequery'
          truncations << PossibleTruncation.new(location, 'ctequery', deparse([v]).size, false)
        when 'cols'
          truncations << PossibleTruncation.new(location, 'cols', deparse(v).size, true)
        end
      end

      truncations
    end
  end
end