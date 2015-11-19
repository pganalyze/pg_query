define_deparse 'TYPENAME' do
  var :result, :string_list

  set :catalog, [:node, :names, 0]
  set :type, [:node, :names, 1]

  condition :catalog, :eq, 'pg_catalog' do
    condition :type, :eq, 'interval' do
      # Intervals are tricky and should be handled in a separate method because
      # they require performing some bitmask operations.
      result { deparse_helper('interval', :node) }
    end
  end

  condition [:node, :setof] do
    append :result, 'SETOF'
  end

  var :arguments, :string
  condition [:node, :typmods] do
    var :parts, :string_list
    each [:node, :typmods], :item do
      append(:parts) { deparse :item }
    end
    append(:arguments) { join :parts, ', ' }
  end

  condition :catalog, :eq, 'pg_catalog' do
    var :type_out, :string
    switch :type do
      switch_case 'bpchar' do
        # char(2) or char(9)
        set(:type_out) { fmt 'char(%s)', :arguments }
      end
      switch_case 'varchar' do
        set(:type_out) { fmt 'varchar(%s)', :arguments }
      end
      switch_case 'numeric' do
        # numeric(3, 5)
        set(:type_out) { fmt 'numeric(%s)', :arguments }
      end
      switch_case('bool') { set :type_out, 'boolean' }
      switch_case('int2') { set :type_out, 'smallint' }
      switch_case('int4') { set :type_out, 'int' }
      switch_case('int8') { set :type_out, 'bigint' }
      switch_case('real') { set :type_out, 'real' }
      switch_case('float4') { set :type_out, 'real' }
      switch_case('float8') { set :type_out, 'double' }
      switch_case('time') { set :type_out, 'time' }
      switch_case('timetz') { set :type_out, 'time with time zone' }
      switch_case('timestamp') { set :type_out, 'timestamp' }
      switch_case('timestamptz') { set :type_out, 'timestamp with time zone' }
      switch_default { throw_error { fmt("Can't deparse type: %s", :type) } }
    end
    append :result, :type_out
  end

  condition :catalog, :not_eq, 'pg_catalog' do
    # Just pass along any custom types.
    # (The pg_catalog types are built-in Postgres system types and are
    #  handled in the switch statement above)
    append(:result) { join [:node, :names], '.' }
  end

  result { join :result, ' ' }
end
