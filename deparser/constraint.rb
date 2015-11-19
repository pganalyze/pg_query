define_deparse 'CONSTRAINT' do
  var :result, :string_list

  condition [:node, :conname] do
    append :result, 'CONSTRAINT'
    append :result, [:node, :conname]
  end

  # NOT_NULL -> NOT NULL
  append(:result) { replace [:node, :contype], '_', ' ' }

  condition [:node, :raw_expr] do
    # Unless it's simple, put parentheses around it
    condition [:node, :raw_expr], :node_type, 'AEXPR' do
      append(:result) { fmt('(%s)') { deparse [:node, :raw_expr] } }
    end

    condition [:node, :raw_expr], :not_node_type, 'AEXPR' do
      append(:result) { deparse [:node, :raw_expr] }
    end
  end

  condition [:node, :keys] do
    append(:result) { fmt('(%s)') { join [:node, :keys], ', ' } }
  end

  condition [:node, :indexname] do
    append(:result) { fmt 'USING INDEX %s', [:node, :indexname] }
  end

  result { join :result, ' ' }
end
