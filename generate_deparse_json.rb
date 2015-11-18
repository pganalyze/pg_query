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
    fail ArgumentError unless [nil, :eq, :node_type, :not_node_type].include?(op)
    fail ArgumentError if op && rarg.nil? # Need either both to be nil, or both be present

    opts = { var_name: var_name, op: op, rarg: rarg }
    opts[:cmds] = collect_cmds(&block) if block_given?
    @cmds << { condition: opts }
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

  def result(&block)
    fail ArgumentError unless block_given?
    @cmds << { result: { cmds: collect_cmds(&block) } }
  end

  def deparse(var_name, context = nil)
    @cmds << { deparse: { var_name: var_name, context: context } }
  end

  def join(var_name, seperator)
    @cmds << { join: { var_name: var_name, seperator: seperator } }
  end

  def fmt(format_string, var_name = nil, &block)
    fail ArgumentError unless block_given? || !var_name.nil?
    opts = { format_string: format_string }
    if block_given?
      opts[:cmd] = collect_cmds(&block)[0]
    else
      opts[:var_name] = var_name
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
