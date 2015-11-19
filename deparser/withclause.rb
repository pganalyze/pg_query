define_deparse 'WITHCLAUSE' do
  var :result, :string_list

  append :result, 'WITH'

  condition [:node, :recursive] do
    append :result, 'RECURSIVE'
  end

  var :parts, :string_list
  each [:node, :ctes], :cte do
    append(:parts) { deparse :cte }
  end
  append(:result) { join :parts, ', ' }

  result { join :result, ' ' }
end
