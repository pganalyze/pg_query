class PgQuery
  def deparse
    output = []
    @parsetree.each do |item|
      output << deparse_item(item)
    end
    output.join(';')
  end

  private

  def deparse_item(item, context = nil) # rubocop:disable Metrics/CyclomaticComplexity
    return if item.nil?

    type = item.keys[0]
    node = item.values[0]

    case type
    when 'RANGEVAR'
      deparse_rangevar(node)
    when 'AEXPR'
      deparse_aexpr(node)
    when 'COLUMNREF'
      deparse_columnref(node)
    when 'A_CONST'
      deparse_a_const(node)
    when 'A_STAR'
      deparse_a_star(node)
    when 'ALIAS'
      deparse_alias(node)
    when 'PARAMREF'
      deparse_paramref(node)
    when 'RESTARGET'
      deparse_restarget(node, context)
    when 'FUNCCALL'
      deparse_funccall(node)
    when 'RANGEFUNCTION'
      deparse_range_function(node)
    when 'AEXPR AND'
      deparse_aexpr_and(node)
    when 'JOINEXPR'
      deparse_joinexpr(node)
    when 'SORTBY'
      deparse_sortby(node)
    when 'SELECT'
      deparse_select(node)
    when 'WITHCLAUSE'
      deparse_with_clause(node)
    when 'COMMONTABLEEXPR'
      deparse_cte(node)
    when 'INSERT INTO'
      deparse_insert_into(node)
    when 'UPDATE'
      deparse_update(node)
    when 'TYPECAST'
      deparse_typecast(node)
    when 'TYPENAME'
      deparse_typename(node)
    else
      fail format("Can't deparse: %s: %s", type, node.inspect)
    end
  end

  def deparse_rangevar(node)
    output = []
    output << node['relname']
    output << deparse_item(node['alias']) if node['alias']
    output.join(' ')
  end

  def deparse_columnref(node)
    node['fields'].map do |field|
      field.is_a?(String) ? field : deparse_item(field)
    end.join('.')
  end

  def deparse_a_const(node)
    node['val'].inspect.gsub('"', '\'')
  end

  def deparse_a_star(_node)
    '*'
  end

  def deparse_alias(node)
    node['aliasname']
  end

  def deparse_paramref(node)
    format('$%d', node['number'])
  end

  def deparse_restarget(node, context)
    if context == :select
      [deparse_item(node['val']), node['name']].compact.join(' AS ')
    elsif context == :update
      [node['name'], deparse_item(node['val'])].compact.join(' = ')
    elsif node['val'].nil?
      node['name']
    else
      fail format("Can't deparse %s in context %s", node.inspect, context)
    end
  end

  def deparse_funccall(node)
    args = Array(node['args']).map { |arg| deparse_item(arg) }
    format('%s(%s)', node['funcname'].join('.'), args.join(', '))
  end

  def deparse_range_function(node)
    output = []
    output << 'LATERAL' if node['lateral']
    output << deparse_item(node['functions'][0][0]) # FIXME: Needs more test cases
    output << deparse_item(node['alias']) if node['alias']
    output.join(' ')
  end

  def deparse_aexpr(node)
    output = []
    output << deparse_item(node['lexpr'])
    output << deparse_item(node['rexpr'])
    output.join(' ' + node['name'][0] + ' ')
  end

  def deparse_aexpr_and(node)
    format('%s AND %s', deparse_item(node['lexpr']), deparse_item(node['rexpr']))
  end

  def deparse_joinexpr(node)
    output = []
    output << deparse_item(node['larg'])
    output << 'LEFT' if node['jointype'] == 1
    output << 'JOIN'
    output << deparse_item(node['rarg'])

    if node['quals']
      output << 'ON'
      output << deparse_item(node['quals'])
    end

    output.join(' ')
  end

  def deparse_sortby(node)
    output = []
    output << deparse_item(node['node'])
    output << 'ASC' if node['sortby_dir'] == 1
    output.join(' ')
  end

  def deparse_with_clause(node)
    output = ['WITH']
    output << 'RECURSIVE' if node['recursive']
    output << node['ctes'].map do |cte|
      deparse_item(cte)
    end.join(', ')
    output.join(' ')
  end

  def deparse_cte(node)
    output = ''
    output += node['ctename']
    output += format('(%s)', node['aliascolnames'].join(', ')) if node['aliascolnames']
    output += format(' AS (%s)', deparse_item(node['ctequery']))
    output
  end

  def deparse_select(node) # rubocop:disable Metrics/CyclomaticComplexity
    output = []

    if node['op'] == 1
      output << deparse_item(node['larg'])
      output << 'UNION'
      output << 'ALL' if node['all']
      output << deparse_item(node['rarg'])
      return output.join(' ')
    end

    output << deparse_item(node['withClause']) if node['withClause']

    if node['targetList']
      output << 'SELECT'
      output << node['targetList'].map do |item|
        deparse_item(item, :select)
      end.join(', ')
    end

    if node['fromClause']
      output << 'FROM'
      output << node['fromClause'].map do |item|
        deparse_item(item)
      end.join(', ')
    end

    if node['whereClause']
      output << 'WHERE'
      output << deparse_item(node['whereClause'])
    end

    if node['valuesLists']
      output << 'VALUES'
      output << node['valuesLists'].map do |value_list|
        '(' + value_list.map { |v| deparse_item(v) }.join(', ') + ')'
      end.join(', ')
    end

    if node['sortClause']
      output << 'ORDER BY'
      output << node['sortClause'].map do |item|
        deparse_item(item)
      end.join(', ')
    end

    output.join(' ')
  end

  def deparse_insert_into(node)
    output = ['INSERT INTO']
    output << deparse_item(node['relation'])

    output << '(' + node['cols'].map do |column|
      deparse_item(column)
    end.join(', ') + ')'

    output << deparse_item(node['selectStmt'])

    output.join(' ')
  end

  def deparse_update(node)
    output = ['UPDATE']
    output << deparse_item(node['relation'])

    if node['targetList']
      output << 'SET'
      node['targetList'].each do |item|
        output << deparse_item(item, :update)
      end
    end

    if node['whereClause']
      output << 'WHERE'
      output << deparse_item(node['whereClause'])
    end

    output.join(' ')
  end

  def deparse_typecast(node)
    if deparse_item(node['typeName']) == :boolean
      deparse_item(node['arg']) == "'t'" ? 'true' : 'false'
    else
      fail format("Can't deparse typecast %s", node.inspect)
    end
  end

  def deparse_typename(node)
    if node['names'] == %w(pg_catalog bool)
      :boolean
    else
      node['names'].join('.')
    end
  end
end
