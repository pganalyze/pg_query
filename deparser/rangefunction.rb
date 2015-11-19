define_deparse 'RANGEFUNCTION' do
  var :result, :string_list

  condition [:node, :lateral] do
    append :result, 'LATERAL'
  end

  # FIXME: Needs more test cases
  append(:result) { deparse [:node, :functions, 0, 0] }

  condition [:node, :alias] do
    append(:result) { deparse [:node, :alias] }
  end

  result { join :result, ' ' }
end
