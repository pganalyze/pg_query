define_deparse 'AEXPR IN' do
  var :result, :string_list

  append(:result) { deparse [:node, :lexpr] }

  condition [:node, :name, 0], :eq, '=' do
    append :result, 'IN'
  end

  condition [:node, :name, 0], :not_eq, '=' do
    append :result, 'NOT IN'
  end

  var :parts, :string_list
  each [:node, :rexpr], :item do
    append(:parts) { deparse :item }
  end
  append(:result) { fmt('(%s)') { join :parts, ', ' } }

  result { join :result, ' ' }
end
