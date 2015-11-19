define_deparse 'TYPECAST' do
  var :typename, :string
  var :arg, :string

  set(:typename) { deparse [:node, :typeName] }
  set(:arg) { deparse [:node, :arg] }

  condition :typename, :eq, 'boolean' do
    condition :arg, :eq, "'t'" do
      result 'true'
    end
    result 'false'
  end

  result { fmt('%s::%s', :arg, :typename) }
end
