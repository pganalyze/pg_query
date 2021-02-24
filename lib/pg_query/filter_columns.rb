class PgQuery
  # Returns a list of columns that the query filters by - this excludes the
  # target list, but includes things like JOIN condition and WHERE clause.
  #
  # Note: This also traverses into sub-selects.
  def filter_columns # rubocop:disable Metrics/CyclomaticComplexity
    load_objects! if @aliases.nil?

    # Get condition items from the parsetree
    statements = @tree.dup
    condition_items = []
    filter_columns = []
    loop do
      statement = statements.shift
      if statement
        if statement[RAW_STMT]
          statements << statement[RAW_STMT][STMT_FIELD]
        elsif statement[SELECT_STMT]
          case statement[SELECT_STMT]['op']
          when 0
            if statement[SELECT_STMT][FROM_CLAUSE_FIELD]
              # FROM subselects
              statement[SELECT_STMT][FROM_CLAUSE_FIELD].each do |item|
                next unless item['RangeSubselect']
                statements << item['RangeSubselect']['subquery']
              end

              # JOIN ON conditions
              condition_items += conditions_from_join_clauses(statement[SELECT_STMT][FROM_CLAUSE_FIELD])
            end

            # WHERE clause
            condition_items << statement[SELECT_STMT]['whereClause'] if statement[SELECT_STMT]['whereClause']

            # CTEs
            if statement[SELECT_STMT]['withClause']
              statement[SELECT_STMT]['withClause']['WithClause']['ctes'].each do |item|
                statements << item['CommonTableExpr']['ctequery'] if item['CommonTableExpr']
              end
            end
          when 1
            statements << statement[SELECT_STMT]['larg'] if statement[SELECT_STMT]['larg']
            statements << statement[SELECT_STMT]['rarg'] if statement[SELECT_STMT]['rarg']
          end
        elsif statement['UpdateStmt']
          condition_items << statement['UpdateStmt']['whereClause'] if statement['UpdateStmt']['whereClause']
        elsif statement['DeleteStmt']
          condition_items << statement['DeleteStmt']['whereClause'] if statement['DeleteStmt']['whereClause']
        end
      end

      # Process both JOIN and WHERE conditions here
      next_item = condition_items.shift
      if next_item
        if next_item[A_EXPR]
          %w[lexpr rexpr].each do |side|
            expr = next_item.values[0][side]
            next unless expr && expr.is_a?(Hash)
            condition_items << expr
          end
        elsif next_item[BOOL_EXPR]
          condition_items += next_item[BOOL_EXPR]['args']
        elsif next_item[ROW_EXPR]
          condition_items += next_item[ROW_EXPR]['args']
        elsif next_item[COLUMN_REF]
          column, table = next_item[COLUMN_REF]['fields'].map { |f| f['String']['str'] }.reverse
          filter_columns << [@aliases[table] || table, column]
        elsif next_item[NULL_TEST]
          condition_items << next_item[NULL_TEST]['arg']
        elsif next_item[BOOLEAN_TEST]
          condition_items << next_item[BOOLEAN_TEST]['arg']
        elsif next_item[FUNC_CALL]
          # FIXME: This should actually be extracted as a funccall and be compared with those indices
          condition_items += next_item[FUNC_CALL]['args'] if next_item[FUNC_CALL]['args']
        elsif next_item[SUB_LINK]
          condition_items << next_item[SUB_LINK]['testexpr']
          statements << next_item[SUB_LINK]['subselect']
        end
      end

      break if statements.empty? && condition_items.empty?
    end

    filter_columns.uniq
  end

  protected

  def conditions_from_join_clauses(from_clause)
    condition_items = []
    from_clause.each do |item|
      next unless item[JOIN_EXPR]

      joinexpr_items = [item[JOIN_EXPR]]
      loop do
        next_item = joinexpr_items.shift
        break unless next_item
        condition_items << next_item['quals'] if next_item['quals']
        %w[larg rarg].each do |side|
          next unless next_item[side][JOIN_EXPR]
          joinexpr_items << next_item[side][JOIN_EXPR]
        end
      end
    end
    condition_items
  end
end
