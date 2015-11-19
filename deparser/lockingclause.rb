define_deparse 'LOCKINGCLAUSE' do
  var :result, :string_list

  switch [:node, :strength] do
    switch_case(0) { append :result, 'FOR KEY SHARE' }
    switch_case(1) { append :result, 'FOR SHARE' }
    switch_case(2) { append :result, 'FOR NO KEY UPDATE' }
    switch_case(3) { append :result, 'FOR UPDATE' }
  end

  condition [:node, :lockedRels] do
    append :result, 'OF'
    var :parts, :string_list
    each [:node, :lockedRels], :item do
      append(:parts) { deparse :item }
    end
    append(:result) { join :parts, ', ' }
  end

  result { join :result, ' ' }
end
