define_deparse 'AEXPR NOT' do
  result { fmt('NOT %s') { deparse [:node, :rexpr] } }
end
