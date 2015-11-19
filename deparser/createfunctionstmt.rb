define_deparse 'CREATEFUNCTIONSTMT' do
  var :result, :string_list

  append :result, 'CREATE FUNCTION'

  var :parameters, :string_list
  each [:node, :parameters], :item do
    append(:parameters) { deparse :item }
  end
  var :arguments, :string
  set(:arguments) { join :parameters, ', ' }

  append(:result) { fmt('%s(%s)', [:node, :funcname, 0], :arguments) }

  append :result, 'RETURNS'
  append(:result) { deparse [:node, :returnType] }

  each [:node, :options], :item do
    append(:result) { deparse :item }
  end

  result { join :result, ' ' }
end
