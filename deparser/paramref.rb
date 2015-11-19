define_deparse 'PARAMREF' do
  condition [:node, :number], :eq, 0 do
    result '?'
  end

  result { fmt('$%d', [:node, :number]) }
end
