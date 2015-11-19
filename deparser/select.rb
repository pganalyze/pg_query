define_deparse 'SELECT' do
  var :result, :string_list

  condition [:node, :op], :eq, 1 do
    append(:result) { deparse [:node, :larg] }
    append :result, 'UNION'
    condition([:node, :all]) { append :result, 'ALL' }
    append(:result) { deparse [:node, :rarg] }
    result { join :result, ' ' }
  end

  condition [:node, :withClause] do
    append(:result) { deparse [:node, :withClause] }
  end

  condition [:node, :targetList] do
    append :result, 'SELECT'
    var :target_list, :string_list
    each [:node, :targetList], :item do
      append(:target_list) { deparse :item, :select }
    end
    append(:result) { join :target_list, ', ' }
  end

  condition [:node, :fromClause] do
    append :result, 'FROM'
    var :from_list, :string_list
    each [:node, :fromClause], :item do
      append(:from_list) { deparse :item }
    end
    append(:result) { join :from_list, ', ' }
  end

  condition [:node, :whereClause] do
    append :result, 'WHERE'
    append(:result) { deparse [:node, :whereClause] }
  end

  condition [:node, :valuesLists] do
    append :result, 'VALUES'
    var :value_lists, :string_list
    each [:node, :valuesLists], :value_list do
      var :parts, :string_list
      each :value_list, :item do
        append(:parts) { deparse :item }
      end
      append(:value_lists) do
        fmt('(%s)') { join :parts, ', ' }
      end
    end
    append(:result) { join :value_lists, ', ' }
  end

  condition [:node, :groupClause] do
    append :result, 'GROUP BY'
    var :parts, :string_list
    each [:node, :groupClause], :item do
      append(:parts) { deparse :item }
    end
    append(:result) { join :parts, ', ' }
  end

  condition [:node, :havingClause] do
    append :result, 'HAVING'
    append(:result) { deparse [:node, :havingClause] }
  end

  condition [:node, :sortClause] do
    append :result, 'ORDER BY'
    var :parts, :string_list
    each [:node, :sortClause], :item do
      append(:parts) { deparse :item }
    end
    append(:result) { join :parts, ', ' }
  end

  condition [:node, :limitCount] do
    append :result, 'LIMIT'
    append(:result) { deparse [:node, :limitCount] }
  end

  condition [:node, :limitOffset] do
    append :result, 'OFFSET'
    append(:result) { deparse [:node, :limitOffset] }
  end

  condition [:node, :lockingClause] do
    each [:node, :lockingClause], :item do
      append(:result) { deparse :item }
    end
  end

  result { join :result, ' ' }
end
