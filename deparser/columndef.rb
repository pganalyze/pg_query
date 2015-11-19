define_deparse 'COLUMNDEF' do
  var :result, :string_list

  condition [:node, :colname] do
    append :result, [:node, :colname]
  end

  condition [:node, :typeName] do
    append(:result) { deparse [:node, :typeName] }
  end

  condition [:node, :raw_default] do
    append :result, 'USING'
    append(:result) { deparse [:node, :raw_default] }
  end

  condition [:node, :constraints] do
    each [:node, :constraints], :item do
      append(:result) { deparse :item }
    end
  end

  result { join :result, ' ' }
end
