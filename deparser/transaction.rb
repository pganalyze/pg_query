define_deparse 'TRANSACTION' do
  var :result, :string_list

  switch [:node, :kind] do
    switch_case(0) { append :result, 'BEGIN' }
    # There is intentionally no case for 1 here
    switch_case(2) { append :result, 'COMMIT' }
    switch_case(3) { append :result, 'ROLLBACK' }
    switch_case(4) { append :result, 'SAVEPOINT' }
    switch_case(5) { append :result, 'RELEASE' }
    switch_case(6) { append :result, 'ROLLBACK TO SAVEPOINT' }
    switch_default { throw_error }
  end

  condition [:node, :options] do
    each [:node, :options], :item do
      append(:result) { deparse :item }
    end
  end

  result { join :result, ' ' }
end
