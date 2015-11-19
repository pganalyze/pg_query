define_deparse 'A_INDIRECTION' do
  var :result, :string_list

  append(:result) { deparse [:node, :arg] }

  each [:node, :indirection], :subnode do
    append(:result) { deparse :subnode }
  end

  result { join :result, '' } # Intentionally not a space
end
