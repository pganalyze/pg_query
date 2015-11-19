define_deparse 'ALIAS' do
  var :result, :string_list

  append :result, [:node, :aliasname]

  condition [:node, :colnames] do
    append(:result) { fmt('(%s)') { join [:node, :colnames], ', ' } }
  end

  result { join :result, '' } # This is intentionally without a space
end
