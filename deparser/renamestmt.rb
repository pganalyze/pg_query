define_deparse 'RENAMESTMT' do
  var :result, :string_list

  condition [:node, :renameType], :eq, 26 do # table
    append :result, 'ALTER TABLE'
    append(:result) { deparse [:node, :relation] }
    append :result, 'RENAME TO'
    append :result, [:node, :newname]
  end

  result { join :result, ' ' }
end
