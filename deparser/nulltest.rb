define_deparse 'NULLTEST' do
  var :result, :string_list

  append(:result) { deparse [:node, :arg] }

  condition [:node, :nulltesttype], :eq, 0 do
    append :result, 'IS NULL'
  end

  condition [:node, :nulltesttype], :eq, 1 do
    append :result, 'IS NOT NULL'
  end

  result { join :result, ' ' }
end
