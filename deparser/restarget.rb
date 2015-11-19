define_deparse 'RESTARGET' do
  condition [:node, :val], :null do
    result { fmt('%s', [:node, :name]) }
  end

  var :val, :string
  set(:val) { deparse [:node, :val] }

  condition [:node, :name], :null do
    result { fmt('%s', :val) }
  end

  condition :context, :eq, 'select' do
    result { fmt('%s AS %s', :val, [:node, :name]) }
  end

  condition :context, :eq, 'update' do
    result { fmt('%s = %s', [:node, :name], :val) }
  end

  throw_error
end
