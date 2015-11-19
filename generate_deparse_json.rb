# rubocop:disable Style/GlobalVars

class DeparseDefinitionProxy
  attr_accessor :cmds

  def initialize
    @cmds = []
  end

  def var(var_name, type)
    @cmds << { var: { var_name: var_name, type: type } }
  end

  def condition(var_name, op = nil, rarg = nil, &block)
    fail ArgumentError unless [nil, :eq, :not_eq, :node_type, :not_node_type, :size, :null].include?(op)

    opts = { var_name: var_name, op: op, rarg: rarg }
    opts[:cmds] = collect_cmds(&block) if block_given?
    @cmds << { condition: opts }
  end

  def switch(var_name, &block)
    fail ArgumentError unless block_given?
    case_branches = []
    default_cmds = []
    collect_cmds(&block).each do |cmd|
      opts = cmd.values[0]
      case cmd.keys[0]
      when :switch_case
        case_branches << opts
      when :switch_default
        default_cmds = opts[:cmds]
      else
        fail ArgumentError
      end
    end
    @cmds << { switch: { var_name: var_name, case_branches: case_branches, default_cmds: default_cmds } }
  end

  def switch_case(value, &block)
    fail ArgumentError unless block_given?
    @cmds << { switch_case: { value: value, cmds: collect_cmds(&block) } }
  end

  def switch_default(&block)
    fail ArgumentError unless block_given?
    @cmds << { switch_default: { cmds: collect_cmds(&block) } }
  end

  def throw_error(&block)
    opts = {}
    opts[:cmds] = collect_cmds(&block) if block_given?
    @cmds << { throw_error: opts }
  end

  def set(var_name, value_or_var_name = nil, &block)
    if value_or_var_name
      if value_or_var_name.is_a?(Symbol) || value_or_var_name.is_a?(Array)
        @cmds << { set: { var_name: var_name, input_var_name: value_or_var_name } }
      else
        @cmds << { set: { var_name: var_name, value: value_or_var_name } }
      end
    elsif block_given?
      @cmds << { set: { var_name: var_name, cmds: collect_cmds(&block) } }
    end
  end

  def append(var_name, value_or_var_name = nil, &block)
    if value_or_var_name
      if value_or_var_name.is_a?(Symbol) || value_or_var_name.is_a?(Array)
        @cmds << { append: { var_name: var_name, input_var_name: value_or_var_name } }
      else
        @cmds << { append: { var_name: var_name, value: value_or_var_name } }
      end
    elsif block_given?
      @cmds << { append: { var_name: var_name, cmds: collect_cmds(&block) } }
    end
  end

  def each(var_name, value_name, &block)
    fail ArgumentError unless block_given?
    @cmds << { each: { var_name: var_name, value_name: value_name, cmds: collect_cmds(&block) } }
  end

  def result(value = nil, &block)
    if value
      @cmds << { result: { value: value } }
    elsif block_given?
      @cmds << { result: { cmds: collect_cmds(&block) } }
    else
      fail ArgumentError
    end
  end

  def deparse(var_name, context = nil)
    @cmds << { deparse: { var_name: var_name, context: context } }
  end

  def deparse_helper(name, *var_names)
    @cmds << { deparse_helper: { name: name, var_names: var_names } }
  end

  def join(var_name, seperator)
    @cmds << { join: { var_name: var_name, seperator: seperator } }
  end

  def fmt(format_string, *var_names, &block)
    fail ArgumentError unless block_given? || !var_names.empty?
    opts = { format_string: format_string }
    if block_given?
      opts[:cmd] = collect_cmds(&block)[0]
    else
      opts[:var_names] = var_names
    end
    @cmds << { format: opts }
  end

  def replace(var_name, pattern, substitute)
    @cmds << { replace: { var_name: var_name, pattern: pattern, substitute: substitute } }
  end

  private

  def collect_cmds(&block)
    proxy = DeparseDefinitionProxy.new
    proxy.instance_eval(&block)
    proxy.cmds
  end
end

$deparse_defs = {}

def define_deparse(node_type, &block)
  proxy = DeparseDefinitionProxy.new
  proxy.instance_eval(&block)
  $deparse_defs[node_type] = proxy.cmds
end

Dir['./deparser/*.rb'].each { |f| require f }

require 'json'

File.write('deparser.json', JSON.pretty_generate($deparse_defs))
