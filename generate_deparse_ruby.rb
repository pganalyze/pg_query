# rubocop:disable Metrics/CyclomaticComplexity

require 'json'

def indent(str, n = 2)
  str.gsub(/(.*)(\z|\n)/, ' ' * n + '\1\2').gsub(/[ \t]+$/, '')
end

def out_cmd(cmd)
  opts = cmd.values[0]

  case cmd.keys[0]
  when 'var'
    case opts['type']
    when 'string'
      format("%s = ''", opts['var_name'])
    when 'string_list'
      format('%s = []', opts['var_name'])
    else
      fail ArgumentError
    end

  when 'condition'
    fail ArgumentError unless opts['cmds']

    out = []

    if opts['op']
      if opts['op'] == 'eq'
        out << format('if %s == %s', var_name(opts['var_name']), opts['rarg'].inspect)
      elsif opts['op'] == 'not_eq'
        out << format('if %s != %s', var_name(opts['var_name']), opts['rarg'].inspect)
      elsif opts['op'] == 'node_type'
        out << format('if %s.keys == [%s]', var_name(opts['var_name']), opts['rarg'].inspect)
      elsif opts['op'] == 'not_node_type'
        out << format('if %s.keys != [%s]', var_name(opts['var_name']), opts['rarg'].inspect)
      elsif opts['op'] == 'size'
        out << format('if %s && %s.size == %d', var_name(opts['var_name']), var_name(opts['var_name']), opts['rarg'])
      elsif opts['op'] == 'null'
        out << format('if !%s', var_name(opts['var_name']))
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

  when 'switch'
    fail ArgumentError unless opts['var_name'] && opts['case_branches'].is_a?(Array)

    out = []
    out << format('case %s', var_name(opts['var_name']))

    opts['case_branches'].each do |branch|
      out << format('when %s', branch['value'].inspect)
      branch['cmds'].each do |subcmd|
        out << indent(out_cmd(subcmd))
      end
    end

    if opts['default_cmds'] && !opts['default_cmds'].empty?
      out << 'else'
      opts['default_cmds'].each do |subcmd|
        out << indent(out_cmd(subcmd))
      end
    end

    out << 'end'
    out.join("\n")

  when 'throw_error'
    if opts['cmds']
      fail ArgumentError unless opts['cmds'].size == 1
      format('fail %s', out_cmd(opts['cmds'][0]))
    else
      'fail ArgumentError'
    end

  when 'set', 'append'
    op = cmd.keys[0] == 'set' ? '=' : '<<'
    if opts['value']
      format("%s %s '%s'", var_name(opts['var_name']), op, opts['value'])
    elsif opts['input_var_name']
      format('%s %s %s', var_name(opts['var_name']), op, var_name(opts['input_var_name']))
    elsif opts['cmds'] && opts['cmds'].size == 1
      format('%s %s %s', var_name(opts['var_name']), op, out_cmd(opts['cmds'][0]))
    else
      fail ArgumentError
    end
  when 'deparse'
    if opts['context']
      format("PgQuery::Deparse.from(%s, '%s')", var_name(opts['var_name']), opts['context'])
    else
      format('PgQuery::Deparse.from(%s)', var_name(opts['var_name']))
    end
  when 'deparse_helper'
    format('PgQuery::DeparseHelper::%s.call(%s)', opts['name'].upcase, opts['var_names'].map { |var| var_name(var) }.join(', '))
  when 'result'
    if opts['cmds'] && opts['cmds'].size == 1
      format('return %s', out_cmd(opts['cmds'][0]))
    elsif opts['value']
      format('return %s', opts['value'].inspect)
    else
      fail ArgumentError
    end
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
      format('format("%s", %s)', opts['format_string'], out_cmd(opts['cmd']))
    elsif opts['var_names']
      format('format("%s", %s)', opts['format_string'], opts['var_names'].map { |var| var_name(var) }.join(', '))
    else
      ArgumentError
    end
  when 'replace'
    format("%s.gsub('%s', '%s')", var_name(opts['var_name']), opts['pattern'], opts['substitute'])
  else
    fail format('Unknown type: %s', cmd.keys[0])
  end
end

def var_name(args)
  if args.is_a?(Array)
    if args.size == 1
      format('%s', args[0])
    elsif args.size == 2
      format('%s[%s]', args[0], args[1].inspect)
    elsif args.size == 3
      format('%s[%s][%s]', args[0], args[1].inspect, args[2].inspect)
    elsif args.size == 4
      format('%s[%s][%s][%s]', args[0], args[1].inspect, args[2].inspect, args[3].inspect)
    else
      fail ArgumentError
    end
  else
    args
  end
end

# Clean old generated files to make renaming easy
system 'rm lib/pg_query/deparse/*.rb'

defs = File.read('deparser.json')

type_to_deparser = []

JSON.parse(defs).each do |node_type, cmds|
  file_format = '''# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::%s
  def self.call(node, context)
%s
  end
end
'''

  result = []
  cmds.each do |cmd|
    result << out_cmd(cmd)
    result << ''
  end

  # FIXME: This should be CamelCase
  ruby_node_type = node_type.gsub(/\s/, '_')

  type_to_deparser << format("'%s' => %s,", node_type, ruby_node_type)

  File.write("lib/pg_query/deparse/#{ruby_node_type.downcase}.rb", format(file_format, ruby_node_type, indent(result.join("\n").strip, 4)))
end

type_to_deparser_file_format = '''# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
module PgQuery::Deparse
  extend self

  # Note: This is not a module-level const to avoid having a strict loading order
  def type_to_deparser(type)
    {
%s
    }[type]
  end
end
'''

File.write('lib/pg_query/deparse/_type_to_deparser.rb', format(type_to_deparser_file_format, indent(type_to_deparser.join("\n").strip, 6)))
