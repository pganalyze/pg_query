# rubocop:disable Metrics/CyclomaticComplexity

def indent(str, n = 2)
  str.gsub(/(.*)(\z|\n)/, ' ' * n + '\1\2').gsub(/[ \t]+$/, '')
end

def out_cmd(cmd)
  opts = cmd.values[0]

  case cmd.keys[0]
  when 'var'
    fail ArgumentError if opts['type'] != 'string_list'

    format('%s = []', opts['var_name'])
  when 'condition'
    fail ArgumentError unless opts['cmds']

    out = []

    if opts['op'] && opts['rarg']
      if opts['op'] == 'eq'
        out << format('if %s == %s', var_name(opts['var_name']), opts['rarg'].inspect)
      elsif opts['op'] == 'node_type'
        out << format('if %s.keys == [%s]', var_name(opts['var_name']), opts['rarg'].inspect)
      elsif opts['op'] == 'not_node_type'
        out << format('if %s.keys != [%s]', var_name(opts['var_name']), opts['rarg'].inspect)
      else
        fail ArgumentError
      end
    else
      out << format('if %s', var_name(opts['var_name']))
    end

    opts['cmds'].each do |subcmd|
      out << indent(out_cmd(subcmd))
    end

    out << 'end'
    out.join("\n")

  when 'append'
    if opts['value']
      format("%s << '%s'", var_name(opts['var_name']), opts['value'])
    elsif opts['input_var_name']
      format('%s << %s', var_name(opts['var_name']), var_name(opts['input_var_name']))
    elsif opts['cmds'] && opts['cmds'].size == 1
      format('%s << %s', var_name(opts['var_name']), out_cmd(opts['cmds'][0]))
    else
      fail ArgumentError
    end
  when 'deparse'
    if opts['context']
      format("PgQuery::Deparse.from(%s, '%s')", var_name(opts['var_name']), opts['context'])
    else
      format('PgQuery::Deparse.from(%s)', var_name(opts['var_name']))
    end
  when 'result'
    fail ArgumentError unless opts['cmds'] && opts['cmds'].size == 1
    format('return %s', out_cmd(opts['cmds'][0]))
  when 'join'
    format("%s.join('%s')", var_name(opts['var_name']), opts['seperator'])
  when 'each'
    out = []
    out << format('%s.each do |%s|', var_name(opts['var_name']), opts['value_name'])
    opts['cmds'].each do |subcmd|
      out << indent(out_cmd(subcmd))
    end
    out << 'end'
    out.join("\n")
  when 'format'
    if opts['cmd']
      format("format('%s', %s)", opts['format_string'], out_cmd(opts['cmd']))
    elsif opts['var_name']
      format("format('%s', %s)", opts['format_string'], var_name(opts['var_name']))
    else
      ArgumentError
    end
  when 'replace'
    format("%s.tr('%s', '%s')", var_name(opts['var_name']), opts['pattern'], opts['substitute'])
  else
    fail format('Unknown type: %s', cmd.keys[0])
  end
end

def var_name(args)
  if args.is_a?(Array)
    fail ArgumentError if args.size != 2
    format("%s['%s']", args[0], args[1])
  else
    args
  end
end

defs = File.read('deparser.json')

require 'json'

JSON.parse(defs).each do |node_type, cmds|
  file_format = '''# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::%s
  def self.call(node)
%s
  end
end
'''

  result = []
  cmds.each do |cmd|
    result << out_cmd(cmd)
    result << ''
  end

  File.write("lib/pg_query/deparse/#{node_type.downcase}.rb", format(file_format, node_type, indent(result.join("\n").strip, 4)))
end
