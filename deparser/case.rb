define_deparse 'CASE' do
  var :result, :string_list

  append :result, 'CASE'

  each [:node, :args], :arg do
    append(:result) { deparse :arg }
  end

  condition [:node, :defresult] do
    append :result, 'ELSE'
    append(:result) { deparse [:node, :defresult] }
  end

  append :result, 'END'

  result { join :result, ' ' }
end
