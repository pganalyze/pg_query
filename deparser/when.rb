define_deparse 'WHEN' do
  var :result, :string_list

  append :result, 'WHEN'

  append(:result) { deparse [:node, :expr] }
  append :result, 'THEN'
  append(:result) { deparse [:node, :result] }

  result { join :result, ' ' }
end
