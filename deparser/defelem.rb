define_deparse 'DEFELEM' do
  condition [:node, :defname], :eq, 'as' do
    result { fmt('AS $$%s$$') { join [:node, :arg], "\n" } }
  end

  condition [:node, :defname], :eq, 'language' do
    result { fmt 'language %s', [:node, :arg] }
  end

  result { fmt('%s', [:node, :arg]) }
end
