define_deparse 'AEXPR OR' do
  var :lexpr, :string
  var :rexpr, :string

  set(:lexpr) { deparse [:node, :lexpr] }
  set(:rexpr) { deparse [:node, :rexpr] }

  # Put parantheses around AND + OR nodes that are inside
  condition [:node, :lexpr], :node_type, 'AEXPR OR' do
    set(:lexpr) { fmt('(%s)', :lexpr) }
  end
  condition [:node, :lexpr], :node_type, 'AEXPR AND' do
    set(:lexpr) { fmt('(%s)', :lexpr) }
  end
  condition [:node, :rexpr], :node_type, 'AEXPR OR' do
    set(:rexpr) { fmt('(%s)', :rexpr) }
  end
  condition [:node, :rexpr], :node_type, 'AEXPR AND' do
    set(:rexpr) { fmt('(%s)', :rexpr) }
  end

  result { fmt('%s OR %s', :lexpr, :rexpr) }
end
