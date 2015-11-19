define_deparse 'AEXPR ANY' do
  var :result, :string_list

  append(:result) { deparse [:node, :lexpr] }
  append :result, [:node, :name, 0]
  append(:result) { fmt('ANY(%s)') { deparse [:node, :rexpr] } }

  result { join :result, ' ' }
end
