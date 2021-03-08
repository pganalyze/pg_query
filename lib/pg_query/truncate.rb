
module PgQuery
  class ParserResult
    PossibleTruncation = Struct.new(:location, :node_type, :length, :is_array)

    # Truncates the query string to be below the specified length, first trying to
    # omit less important parts of the query, and only then cutting off the end.
    def truncate(max_length) # rubocop:disable Metrics/CyclomaticComplexity
      output = deparse

      # Early exit if we're already below the max length
      return output if output.size <= max_length

      truncations = find_possible_truncations

      # Truncate the deepest possible truncation that is the longest first
      truncations.sort_by! { |t| [-t.location.size, -t.length] }

      tree = dup_tree
      truncations.each do |truncation|
        next if truncation.length < 3

        find_tree_location(tree, truncation.location) do |node, _k|
          dummy_column_ref = PgQuery::Node.new(column_ref: PgQuery::ColumnRef.new(fields: [PgQuery::Node.new(string: PgQuery::String.new(str: '…'))]))
          case truncation.node_type
          when :target_list
            node.target_list.replace(
              [
                PgQuery::Node.new(res_target: PgQuery::ResTarget.new(val: dummy_column_ref))
              ]
            )
          when :where_clause
            node.where_clause = dummy_column_ref
          when :ctequery
            node.ctequery = PgQuery::Node.new(select_stmt: PgQuery::SelectStmt.new(where_clause: dummy_column_ref, op: :SETOP_NONE))
          when :cols
            node.cols.replace([PgQuery::Node.from(PgQuery::ResTarget.new(name: '…'))])
          else
            raise ArgumentError, format('Unexpected truncation node type: %s', truncation.node_type)
          end
        end

        output = PgQuery.deparse(tree).gsub('SELECT WHERE "…"', '...').gsub('"…"', '...')
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
        when :target_list
          length = PgQuery.deparse_stmt(PgQuery::SelectStmt.new(k => v.to_a, op: :SETOP_NONE)).size - 7 # 'SELECT '.size
          truncations << PossibleTruncation.new(location, :target_list, length, true)
        when :where_clause
          length = PgQuery.deparse_expr(v).size
          truncations << PossibleTruncation.new(location, :where_clause, length, false)
        when :ctequery
          length = PgQuery.deparse_stmt(v[v.node.to_s]).size
          truncations << PossibleTruncation.new(location, :ctequery, length, false)
        when :cols
          length = PgQuery.deparse_stmt(
            PgQuery::InsertStmt.new(
              relation: PgQuery::RangeVar.new(relname: 'x', inh: true),
              cols: v.to_a
            )
          ).size - 31 # "INSERT INTO x () DEFAULT VALUES".size
          truncations << PossibleTruncation.new(location, :cols, length, true)
        end
      end

      truncations
    end
  end
end
