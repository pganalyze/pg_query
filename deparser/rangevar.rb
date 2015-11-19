define_deparse 'RANGEVAR' do
  condition :context, :eq, 'relpersistence' do
    # The PG parser adds several pieces of view data onto the RANGEVAR
    # that need to be printed before the actual deparse is called.
    switch [:node, :relpersistence] do
      switch_case('t') { result 'TEMPORARY' }
      switch_case('u') { result 'UNLOGGED' }
      switch_case('p') { result '' }
      switch_default { throw_error { fmt('Unknown persistence type %s', [:node, :relpersistence]) } }
    end
  end

  var :result, :string_list

  condition [:node, :inhOpt], :eq, 0 do
    append :result, 'ONLY'
  end

  append :result, [:node, :relname]

  condition [:node, :alias] do
    append(:result) { deparse [:node, :alias] }
  end

  result { join :result, ' ' }
end
