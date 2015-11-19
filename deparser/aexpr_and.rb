define_deparse 'AEXPR AND' do
  var :lexpr, :string
  var :rexpr, :string

  set(:lexpr) { deparse [:node, :lexpr] }
  set(:rexpr) { deparse [:node, :rexpr] }

  # Only put parantheses around OR nodes that are inside this one
  condition [:node, :lexpr], :node_type, 'AEXPR OR' do
    set(:lexpr) { fmt('(%s)', :lexpr) }
  end
  condition [:node, :rexpr], :node_type, 'AEXPR OR' do
    set(:rexpr) { fmt('(%s)', :rexpr) }
  end

  result { fmt('%s AND %s', :lexpr, :rexpr) }
end
