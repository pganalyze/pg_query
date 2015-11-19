define_deparse 'SUBLINK' do
  var :subselect, :string
  set(:subselect) { deparse [:node, :subselect] }

  condition [:node, :subLinkType], :eq, 2 do
    condition [:node, :operName, 0], :eq, '=' do
      var :testexpr, :string
      set(:testexpr) { deparse [:node, :testexpr] }
      result { fmt('%s IN (%s)', :testexpr, :subselect) }
    end
  end

  condition [:node, :subLinkType], :eq, 0 do
    result { fmt('EXISTS(%s)', :subselect) }
  end

  result { fmt('(%s)', :subselect) }
end
