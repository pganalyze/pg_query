define_deparse 'A_ARRAYEXPR' do
  var :result, :string_list

  each [:node, :elements], :element do
    append(:result) { deparse :element }
  end

  result { fmt('ARRAY[%s]') { join :result, ', ' } }
end
