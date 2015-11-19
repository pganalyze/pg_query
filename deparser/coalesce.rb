define_deparse 'COALESCE' do
  var :args, :string_list

  each [:node, :args], :arg do
    append(:args) { deparse :arg }
  end

  result { fmt('COALESCE(%s)') { join :args, ', ' } }
end
