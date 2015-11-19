define_deparse 'FUNCCALL' do
  var :result, :string_list

  var :args, :string_list
  condition [:node, :args] do # e.g. SUM(a, b)
    each [:node, :args], :arg do
      append(:args) { deparse :arg }
    end
  end
  condition [:node, :agg_star] do # e.g. COUNT(*)
    append :args, '*'
  end
  var :args_str, :string
  set(:args_str) { join :args, ', ' }

  var :name, :string_list
  each [:node, :funcname], :item do
    condition :item, :not_eq, 'pg_catalog' do
      append :name, :item
    end
  end
  var :name_str, :string
  set(:name_str) { join :name, '.' }

  append(:result) { fmt('%s(%s)', :name_str, :args_str) }

  condition [:node, :over] do
    append(:result) { fmt('OVER (%s)') { deparse [:node, :over] } }
  end

  result { join :result, ' ' }
end
