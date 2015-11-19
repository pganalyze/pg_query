define_deparse 'ALTER TABLE CMD' do
  var :result, :string_list

  set(:command_and_options) { deparse_helper('alter_table_commands', :node) }
  set :command, [:command_and_options, 0]
  set :options, [:command_and_options, 1]

  condition :command do
    append :result, [:command]
  end

  condition [:node, :missing_ok] do
    append :result, 'IF EXISTS'
  end

  condition [:node, :name] do
    append :result, [:node, :name]
  end

  condition :options do
    append :result, [:options]
  end

  condition [:node, :def] do
    append(:result) { deparse [:node, :def] }
  end

  condition [:node, :behavior], :eq, 1 do
    append :result, 'CASCADE'
  end

  result { join :result, ' ' }
end
