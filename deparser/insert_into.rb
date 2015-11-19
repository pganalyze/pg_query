define_deparse 'INSERT INTO' do
  var :result, :string_list

  condition [:node, :withClause] do
    append(:result) { deparse [:node, :withClause] }
  end

  append :result, 'INSERT INTO'
  append(:result) { deparse [:node, :relation] }

  condition [:node, :cols] do
    var :parts, :string_list
    each [:node, :cols], :column do
      append(:parts) { deparse :column }
    end
    append(:result) { fmt('(%s)') { join :parts, ', ' } }
  end

  append(:result) { deparse [:node, :selectStmt] }

  result { join :result, ' ' }
end
