define_deparse 'SORTBY' do
  var :result, :string_list

  append(:result) { deparse [:node, :node] }

  condition [:node, :sortby_dir], :eq, 1 do
    append :result, 'ASC'
  end

  condition [:node, :sortby_dir], :eq, 2 do
    append :result, 'DESC'
  end

  result { join :result, ' ' }
end
