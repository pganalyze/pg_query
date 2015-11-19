define_deparse 'UPDATE' do
  var :result, :string_list

  condition [:node, :withClause] do
    append(:result) { deparse [:node, :withClause] }
  end

  append(:result, 'UPDATE')
  append(:result) { deparse [:node, :relation] }

  condition [:node, :targetList] do
    append(:result, 'SET')
    each [:node, :targetList], :item do
      append(:result) { deparse :item, 'update' }
    end
  end

  condition [:node, :whereClause] do
    append(:result, 'WHERE')
    append(:result) { deparse [:node, :whereClause] }
  end

  condition [:node, :returningList] do
    append(:result, 'RETURNING')
    var :parts, :string_list
    each [:node, :returningList], :item do
      # RETURNING is formatted like a SELECT
      append(:parts) { deparse :item, 'select' }
    end
    append(:result) { join :parts, ', ' }
  end

  result { join :result, ' ' }
end
