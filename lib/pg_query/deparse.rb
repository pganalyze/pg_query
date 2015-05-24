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
    when 'ALIAS'
      deparse_alias(node)
    when 'PARAMREF'
      deparse_paramref(node)
    when 'RESTARGET'
      deparse_restarget(node, context)
    when 'FUNCCALL'
      deparse_funccall(node)
    when 'AEXPR AND'
      deparse_aexpr_and(node)
    when 'JOINEXPR'
      deparse_joinexpr(node)
    when 'SORTBY'
      deparse_sortby(node)
    when 'SELECT'
      deparse_select(node)
    when 'INSERT INTO'
      deparse_insert_into(node)
    when 'UPDATE'
      deparse_update(node)
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
    node['fields'].join('.')
  end

  def deparse_a_const(node)
    node['val'].inspect.gsub('"', '\'')
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
    args = node['args'].map { |arg| deparse_item(arg) }
    format('%s(%s)', node['funcname'].join('.'), args.join(', '))
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

  def deparse_select(node)
    output = []

    if node['targetList']
      output << 'SELECT'
      output << node['targetList'].map do |item|
        deparse_item(item, :select)
      end.join(', ')
    end

    if node['fromClause']
      output << 'FROM'
      node['fromClause'].each do |item|
        output << deparse_item(item)
      end
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
end
