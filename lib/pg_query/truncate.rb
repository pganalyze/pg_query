class PgQuery
  PossibleTruncation = Struct.new(:location, :node_type, :length)

  # Truncates the query string to be below the specified length, first trying to
  # omit less important parts of the query, and only then cutting off the end.
  def truncate(max_length)
    tree   = deep_dup(parsetree)
    output = deparse(tree)

    # Early exit if we're already below the max length
    return output if output.size <= max_length

    truncations = []

    # (1) Save possible truncations, their location, type & lengths
    treewalker! tree do |expr, k, v, location|
      if k == 'targetList'
        length = deparse([{ 'SELECT' => { k => v } }]).size - 'SELECT '.size

        truncations << PossibleTruncation.new(location, 'targetList', length)
      end
    end

    # TODO: Sort by most promising truncation

    truncations.each do |truncation|
      next if truncation.length < 3

      find_tree_location(tree, truncation.location) do |expr, k|
        expr[k] = [{ 'A_TRUNCATED' => nil }]
      end

      output = deparse(tree)
      return output if output.size <= max_length
    end

    # We couldn't do a proper smart truncation, so we need a hard cut-off
    output[0..max_length - 4] + '...'
  end
end
