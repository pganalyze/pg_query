define_deparse 'COMMONTABLEEXPR' do
  var :result, :string_list

  append :result, [:node, :ctename]

  condition [:node, :aliascolnames] do
    append(:result) { fmt('(%s)') { join [:node, :aliascolnames], ', ' } }
  end

  append(:result) { fmt('AS (%s)') { deparse [:node, :ctequery] } }

  result { join :result, ' ' }
end
