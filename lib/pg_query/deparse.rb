class PgQuery
  def deparse
    output = []
    @parsetree.each do |item|
      output << deparse_item(item)
    end
    output.join(';')
  end

  private

  def deparse_item(item)
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
    when 'RESTARGET'
      deparse_restarget(node)
    when 'AEXPR AND'
      deparse_aexpr_and(node)
    when 'SELECT'
      deparse_select(node)
    when 'INSERT INTO'
      deparse_insert_into(node)
    else
      raise format("Can't deparse: %s: %s", type, node.inspect)
    end
  end

  def deparse_rangevar(node)
    node['relname']
  end

  def deparse_columnref(node)
    node['fields'].join('.')
  end

  def deparse_a_const(node)
    node['val'].inspect.gsub('"', '\'')
  end

  def deparse_restarget(node)
    [deparse_item(node['val']), node['name']].compact.join(' AS ')
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

  def deparse_select(node)
    output = []

    if node['targetList']
      output << 'SELECT'
      node['targetList'].each do |item|
        output << deparse_item(item)
      end
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
end
