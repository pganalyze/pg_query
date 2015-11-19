define_deparse 'COLUMNREF' do
  var :result, :string_list

  each [:node, :fields], :field do
    append(:result) { deparse :field }
  end

  result { join :result, '.' } # This is intentionally not a space
end
