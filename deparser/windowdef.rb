define_deparse 'WINDOWDEF' do
  var :result, :string_list

  condition [:node, :partitionClause] do
    append :result, 'PARTITION BY'
    var :parts, :string_list
    each [:node, :partitionClause], :item do
      append(:parts) { deparse :item }
    end
    append(:result) { join :parts, ', ' }
  end

  condition [:node, :orderClause] do
    append :result, 'ORDER BY'
    var :parts, :string_list
    each [:node, :orderClause], :item do
      append(:parts) { deparse :item }
    end
    append(:result) { join :parts, ', ' }
  end

  result { join :result, ' ' }
end
