define_deparse 'CREATESTMT' do
  var :result, :string_list

  append :result, 'CREATE'

  var :relpersistence, :string
  set(:relpersistence) { deparse [:node, :relation], 'relpersistence' }
  condition [:relpersistence], :not_eq, '' do
    append :result, :relpersistence
  end

  append :result, 'TABLE'

  condition [:node, :if_not_exists] do
    append :result, 'IF NOT EXISTS'
  end

  append(:result) { deparse [:node, :relation] }

  var :parts, :string_list
  each [:node, :tableElts], :item do
    append(:parts) { deparse :item }
  end
  append(:result) { fmt('(%s)') { join :parts, ', ' } }

  condition [:node, :inhRelations] do
    append :result, 'INHERITS'
    var :other_parts, :string_list
    each [:node, :inhRelations], :relation do
      append(:other_parts) { deparse :relation }
    end
    append(:result) { fmt('(%s)') { join :other_parts, ', ' } }
  end

  result { join :result, ' ' }
end
