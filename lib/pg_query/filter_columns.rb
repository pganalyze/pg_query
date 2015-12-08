class PgQuery
  # Returns a list of columns that the query filters by - this excludes the
  # target list, but includes things like JOIN condition and WHERE clause.
  #
  # Note: This also traverses into sub-selects.
  def filter_columns # rubocop:disable Metrics/CyclomaticComplexity
    load_tables_and_aliases! if @aliases.nil?

    # Get condition items from the parsetree
    statements = @parsetree.dup
    condition_items = []
    filter_columns = []
    loop do
      statement = statements.shift
      if statement
        if statement['SelectStmt']
          if statement['SelectStmt']['op'] == 0
            if statement['SelectStmt']['fromClause']
              # FROM subselects
              statement['SelectStmt']['fromClause'].each do |item|
                next unless item['RangeSubselect']
                statements << item['RangeSubselect']['subquery']
              end

              # JOIN ON conditions
              condition_items += conditions_from_join_clauses(statement['SelectStmt']['fromClause'])
            end

            # WHERE clause
            condition_items << statement['SelectStmt']['whereClause'] if statement['SelectStmt']['whereClause']

            # CTEs
            if statement['SelectStmt']['withClause']
              statement['SelectStmt']['withClause']['WithClause']['ctes'].each do |item|
                statements << item['CommonTableExpr']['ctequery'] if item['CommonTableExpr']
              end
            end
          elsif statement['SelectStmt']['op'] == 1
            statements << statement['SelectStmt']['larg'] if statement['SelectStmt']['larg']
            statements << statement['SelectStmt']['rarg'] if statement['SelectStmt']['rarg']
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
        if next_item['A_Expr']
          %w(lexpr rexpr).each do |side|
            expr = next_item.values[0][side]
            next unless expr && expr.is_a?(Hash)
            condition_items << expr
          end
        elsif next_item['RowExpr']
          condition_items += next_item['RowExpr']['args']
        elsif next_item['ColumnRef']
          column, table = next_item['ColumnRef']['fields'].map { |f| f['String']['str'] }.reverse
          filter_columns << [@aliases[table] || table, column]
        elsif next_item['NullTest']
          condition_items << next_item['NullTest']['arg']
        elsif next_item['FuncCall']
          # FIXME: This should actually be extracted as a funccall and be compared with those indices
          condition_items += next_item['FuncCall']['args'] if next_item['FuncCall']['args']
        elsif next_item['SubLink']
          condition_items << next_item['SubLink']['testexpr']
          statements << next_item['SubLink']['subselect']
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
      next unless item['JOINEXPR']

      joinexpr_items = [item['JOINEXPR']]
      loop do
        next_item = joinexpr_items.shift
        break unless next_item
        condition_items << next_item['quals'] if next_item['quals']
        %w(larg rarg).each do |side|
          next unless next_item[side]['JOINEXPR']
          joinexpr_items << next_item[side]['JOINEXPR']
        end
      end
    end
    condition_items
  end
end
