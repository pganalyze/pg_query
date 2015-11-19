define_deparse 'ROW' do
  var :args, :string_list
  each [:node, :args], :arg do
    append(:args) { deparse :arg }
  end

  result { fmt('ROW(%s)') { join :args, ', ' } }
end
