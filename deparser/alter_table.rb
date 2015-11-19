define_deparse 'ALTER TABLE' do
  var :result, :string_list

  append :result, 'ALTER TABLE'

  append(:result) { deparse [:node, :relation] }

  var :cmds, :string_list
  each [:node, :cmds], :cmd do
    append(:cmds) { deparse :cmd }
  end
  append(:result) { join :cmds, ', ' }

  result { join :result, ' ' }
end
