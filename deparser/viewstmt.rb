define_deparse 'VIEWSTMT' do
  var :result, :string_list

  append :result, 'CREATE'

  condition [:node, :replace] do
    append :result, 'OR REPLACE'
  end

  var :relpersistence, :string
  set(:relpersistence) { deparse [:node, :view], 'relpersistence' }
  condition [:relpersistence], :not_eq, '' do
    append :result, :relpersistence
  end

  append :result, 'VIEW'
  append(:result) { deparse [:node, :view] } # output << node['view']['RANGEVAR']['relname']

  condition [:node, :aliases] do
    append(:result) { fmt('(%s)') { join [:node, :aliases], ', ' } }
  end

  append :result, 'AS'
  append(:result) { deparse [:node, :query] }

  condition [:node, :withCheckOption], :eq, 1 do
    append :result, 'WITH CHECK OPTION'
  end

  condition [:node, :withCheckOption], :eq, 2 do
    append :result, 'WITH CASCADED CHECK OPTION'
  end

  result { join :result, ' ' }
end
