# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::TYPENAME
  def self.call(node, context)
    result = []

    catalog = node["names"][0]

    type = node["names"][1]

    if catalog == "pg_catalog"
      if type == "interval"
        return PgQuery::DeparseHelper::INTERVAL.call(node)
      end
    end

    if node["setof"]
      result << 'SETOF'
    end

    arguments = ''

    if node["typmods"]
      parts = []
      node["typmods"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      arguments << parts.join(', ')
    end

    if catalog == "pg_catalog"
      type_out = ''
      case type
      when "bpchar"
        type_out = format("char(%s)", arguments)
      when "varchar"
        type_out = format("varchar(%s)", arguments)
      when "numeric"
        type_out = format("numeric(%s)", arguments)
      when "bool"
        type_out = 'boolean'
      when "int2"
        type_out = 'smallint'
      when "int4"
        type_out = 'int'
      when "int8"
        type_out = 'bigint'
      when "real"
        type_out = 'real'
      when "float4"
        type_out = 'real'
      when "float8"
        type_out = 'double'
      when "time"
        type_out = 'time'
      when "timetz"
        type_out = 'time with time zone'
      when "timestamp"
        type_out = 'timestamp'
      when "timestamptz"
        type_out = 'timestamp with time zone'
      else
        fail format("Can't deparse type: %s", type)
      end
      result << type_out
    end

    if catalog != "pg_catalog"
      result << node["names"].join('.')
    end

    return result.join(' ')
  end
end
