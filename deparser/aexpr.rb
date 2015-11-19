define_deparse 'AEXPR' do
  var :result, :string_list

  append(:result) { deparse [:node, :lexpr], 'aexpr' }
  append :result, [:node, :name, 0]
  append(:result) { deparse [:node, :rexpr], 'aexpr' }

  condition :context, :eq, 'aexpr' do
    # This is a nested expression, add parentheses.
    result { fmt('(%s)') { join :result, ' ' } }
  end

  result { join :result, ' ' }
end
