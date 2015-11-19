define_deparse 'RANGESUBSELECT' do
  var :result, :string_list

  append(:result) { fmt('(%s)') { deparse [:node, :subquery] } }

  condition [:node, :alias] do
    append(:result) { deparse [:node, :alias] }
  end

  result { join :result, ' ' }
end
