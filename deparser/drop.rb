define_deparse 'DROP' do
  var :result, :string_list

  append :result, 'DROP'

  condition [:node, :removeType], :eq, 26 do
    append :result, 'TABLE'
  end

  condition [:node, :concurrent] do
    append :result, 'CONCURRENTLY'
  end

  condition [:node, :missing_ok] do
    append :result, 'IF EXISTS'
  end

  append(:result) { join [:node, :objects], ', ' }

  condition [:node, :behavior], :eq, 1 do
    append :result, 'CASCADE'
  end

  result { join :result, ' ' }
end
