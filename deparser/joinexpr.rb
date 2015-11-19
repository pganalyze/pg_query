define_deparse 'JOINEXPR' do
  var :result, :string_list

  append(:result) { deparse [:node, :larg] }

  condition [:node, :jointype], :eq, 1 do
    append :result, 'LEFT'
  end

  condition [:node, :jointype], :eq, 0 do
    condition [:node, :quals], :null do
      append :result, 'CROSS'
    end
  end

  append :result, 'JOIN'

  append(:result) { deparse [:node, :rarg] }

  condition [:node, :quals] do
    append :result, 'ON'
    append(:result) { deparse [:node, :quals] }
  end

  result { join :result, ' ' }
end
