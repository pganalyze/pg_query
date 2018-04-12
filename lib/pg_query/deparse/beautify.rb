class PgQuery

  def beautify( tree = @tree )
    tree.map do |item|
      Deparse.beautify(item)
    end.join('; ')
  end

  module Deparse
    def beautify(item)
      beautify_item(item)
    end

    private

    def beautify_item(item, context = nil)
      return if item.nil?
      return item if item.is_a?(Integer)

      type = item.keys[0]
      node = item[type]

      case type
      when BOOL_EXPR
        case node['boolop']
        when BOOL_EXPR_AND
          beautify_bool_expr_and(node, context)
        when BOOL_EXPR_OR
          beautify_bool_expr_or(node, context)
        when BOOL_EXPR_NOT
          deparse_bool_expr_not(node)
        end
      when CASE_EXPR
        beautify_case(node)
      when COMMON_TABLE_EXPR
        beautify_cte(node)
      when JOIN_EXPR
        beautify_joinexpr(node)
      when RAW_STMT
        beautify_raw_stmt(node)
      when RANGE_SUBSELECT
        beautify_rangesubselect(node)
      when RES_TARGET
        beautify_restarget(node, context)
      when SELECT_STMT
        beautify_select(node)
      when WITH_CLAUSE
        beautify_with_clause(node)
      else
        deparse_item(item, context)
      end
    end

    def beautify_case(node)
      output = [ node['arg'] ? 'CASE ' +  beautify_item(node['arg']) : 'CASE' ]
      output += node['args'].map { |arg| '  ' + beautify_item(arg) }
      if node['defresult']
        output << '  ELSE ' + beautify_item(node['defresult'])
      end
      output << 'END'
      output.join("\n")
    end

    def beautify_indent_each_line(input, prefix = nil)
      use_prefix = prefix.nil? ? '  ' : ' ' * prefix
      input.lines.map { |l| use_prefix + l }.join('')
    end

    def beautify_raw_stmt(node)
      beautify_item(node[STMT_FIELD])
    end

    def beautify_joinexpr(node)
      output = []
      output << beautify_item(node['larg'])
      next_line = []
      case node['jointype']
      when 0
        if node['isNatural']
          next_line << 'NATURAL'
        elsif node['quals'].nil? && node['usingClause'].nil?
          next_line << 'CROSS'
        end
      when 1
        next_line << 'LEFT'
      when 2
        next_line << 'FULL'
      when 3
        next_line << 'RIGHT'
      end
      next_line << 'JOIN'
      next_line << beautify_item(node['rarg'])

      if node['quals']
        next_line << 'ON'
        next_line << beautify_item(node['quals'], next_line.join(' ').lines.last.length + 1)
      end

      next_line << format('USING (%s)', node['usingClause'].map { |n| beautify_item(n) }.join(', ')) if node['usingClause']
      output << next_line.join(' ')

      output.join("\n")
    end

    def beautify_rangesubselect(node)
      output = "(\n" + beautify_indent_each_line( beautify_item(node['subquery']) ) + "\n)"
      if node['alias']
        output + ' ' + beautify_item(node['alias'])
      else
        output
      end
    end

    def beautify_select(node)
      output = []

      if node['op'] == 1
        output << beautify_item(node['larg'])
        if node['all']
          output << 'UNION ALL'
        else
          output << 'UNION'
        end
        output << beautify_item(node['rarg'])
        return output.join("\n")
      end

      output << beautify_item(node['withClause']) if node['withClause']

      if node[TARGET_LIST_FIELD]
        output << 'SELECT'
        if node['distinctClause']
          if node['distinctClause'].first.nil?
            output << '  DISTINCT'
          else
            output << '  DISTINCT ON ('
            last_distinct_index = node['distinctClause'].length - 1
            node['distinctClause'].each_with_index do |item, index|
              l = beautify_indent_each_line( beautify_item(item, :select), 4 )
              l += "," if index < last_distinct_index
              output << l
            end
            output << '  )'
          end
        end
        last_target_index = node[TARGET_LIST_FIELD].length - 1
        node[TARGET_LIST_FIELD].each_with_index do |item, index|
          l = beautify_indent_each_line( beautify_item(item, :select) )
          l += "," if index < last_target_index
          output << l
        end
      end

      if node[FROM_CLAUSE_FIELD]
        output << 'FROM'
        last_from_index = node[FROM_CLAUSE_FIELD].length - 1
        node[FROM_CLAUSE_FIELD].each_with_index do |item, index|
          l = beautify_indent_each_line( beautify_item( item ) )
          l += "," if index < last_from_index
          output << l
        end
      end

      if node['whereClause']
        output << 'WHERE'
        output << beautify_indent_each_line( beautify_item(node['whereClause']) )
      end

      if node['valuesLists']
        output << 'VALUES'
        output << node['valuesLists'].map do |value_list|
          '(' + value_list.map { |v| beautify_item(v) }.join(', ') + ')'
        end.join(', ')
      end

      if node['groupClause']
        output << 'GROUP BY'
        last_group_index = node['groupClause'].length - 1
        node['groupClause'].each_with_index do |item, index|
          l = "  " + beautify_item(item)
          l += "," if index < last_group_index
          output << l
        end.join("\n")
      end

      if node['havingClause']
        output << 'HAVING'
        output << beautify_indent_each_line( beautify_item(node['havingClause']) )
      end

      if node['sortClause']
        output << 'ORDER BY'
        last_sort_index = node['sortClause'].length - 1
        node['sortClause'].each_with_index do |item, index|
          l = "  " + beautify_item(item)
          l += "," if index < last_sort_index
          output << l
        end.join("\n")
      end

      if node['limitCount']
        output << 'LIMIT'
        output << '  ' + beautify_item(node['limitCount'])
      end

      if node['limitOffset']
        output << 'OFFSET'
        output << '  ' + beautify_item(node['limitOffset'])
      end

      if node['lockingClause']
        node['lockingClause'].map do |item|
          output << beautify_item(item)
        end
      end

      output.join("\n")
    end

    def beautify_bool_expr_and(node, context = nil)
      prefix = context.nil? ? "" : " " * context
      # Only put parantheses around OR nodes that are inside this one
      node['args'].map do |arg|
        if [BOOL_EXPR_OR].include?(arg.values[0]['boolop'])
          "(\n" + beautify_indent_each_line( beautify_item(arg), context.nil? ? nil : context + 2) + "\n" + prefix + ")"
        else
          beautify_item(arg)
        end
      end.join(" AND\n" + prefix)
    end

    def beautify_bool_expr_or(node, context = nil)
      prefix = context.nil? ? "" : " " * context
      # Put parantheses around AND + OR nodes that are inside
      node['args'].map do |arg|
        if [BOOL_EXPR_AND, BOOL_EXPR_OR].include?(arg.values[0]['boolop'])
          "(\n" + beautify_indent_each_line( beautify_item(arg), context.nil? ? nil : context + 2) + "\n" + prefix + ")"
        else
          beautify_item(arg)
        end
      end.join(" OR\n" + prefix)
    end

    def beautify_restarget(node, context)
      if context == :select
        [beautify_item(node['val']), node['name']].compact.join(' AS ')
      elsif context == :update
        [node['name'], beautify_item(node['val'])].compact.join(' = ')
      elsif node['val'].nil?
        node['name']
      else
        raise format("Can't beautify %s in context %s", node.inspect, context)
      end
    end

    def beautify_with_clause(node)
      output = [ node['recursive'] ? 'WITH RECURSIVE' : 'WITH' ]
      output << node['ctes'].map do |cte|
        beautify_item(cte)
      end.join(', ')
      output.join(' ')
    end

    def beautify_cte(node)
      output = []
      output << node['ctename']
      output << format('(%s)', node['aliascolnames'].map { |n| beautify_item(n) }.join(', ')) if node['aliascolnames']
      output << format("AS (\n%s\n)", beautify_indent_each_line( beautify_item(node['ctequery'])) )
      output.join(' ')
    end

  end
end
