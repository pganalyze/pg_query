class PgQuery
  # Legacy parsetree from 0.7 and earlier versions - migrate to "tree" format if you can
  def parsetree # rubocop:disable Metrics/CyclomaticComplexity
    @parsetree ||= transform_nodes!(@tree) do |node|
      key = node.keys[0]
      new_key = LEGACY_NODE_NAMES[key] || key.upcase

      case key
      when A_CONST
        transform_parsetree_a_const(node)
      when A_EXPR
        transform_string_list(node[A_EXPR]['name'])
        new_key = LEGACY_A_EXPR_NAMES[node[A_EXPR]['kind']]
        node[A_EXPR].delete('kind')
      when COLUMN_REF
        transform_string_list(node[COLUMN_REF]['fields'])
      when CREATE_FUNCTION_STMT
        transform_string_list(node[CREATE_FUNCTION_STMT]['funcname'])
      when CREATE_TRIG_STMT
        transform_string_list(node[CREATE_TRIG_STMT]['funcname'])
      when CONSTRAINT
        node[CONSTRAINT]['contype'] = CONSTRAINT_TYPES[node[CONSTRAINT]['contype']]
        transform_string_list(node[CONSTRAINT]['keys'])
      when COPY_STMT
        transform_string_list(node[COPY_STMT]['attlist'])
      when DEF_ELEM
        node[DEF_ELEM]['arg'] = node[DEF_ELEM]['arg'][INTEGER]['ival'] if node[DEF_ELEM]['arg'].is_a?(Hash) && node[DEF_ELEM]['arg'].keys[0] == INTEGER
        node[DEF_ELEM]['arg'] = node[DEF_ELEM]['arg'][STRING]['str'] if node[DEF_ELEM]['arg'].is_a?(Hash) && node[DEF_ELEM]['arg'].keys[0] == STRING
        transform_string_list(node[DEF_ELEM]['arg']) if node[DEF_ELEM]['arg'].is_a?(Array)
      when DROP_STMT
        node[DROP_STMT]['objects'].each { |obj| transform_string_list(obj) }
      when GRANT_ROLE_STMT
        transform_string_list(node[GRANT_ROLE_STMT]['grantee_roles'])
      when TYPE_NAME
        transform_string_list(node[TYPE_NAME]['names'])
      end

      node[new_key] = node.delete(key)

      # Transform
      # - UPCASE node names (and rename some of them)
      # - Fix up value nodes
    end
  end

  private

  LEGACY_NODE_NAMES = {
    SELECT_STMT => 'SELECT',
    ALTER_TABLE_CMD => 'ALTER TABLE CMD',
    ALTER_TABLE_STMT => 'ALTER TABLE',
    CHECK_POINT_STMT => 'CHECKPOINT',
    CREATE_SCHEMA_STMT => 'CREATE SCHEMA',
    CREATE_TABLE_AS_STMT => 'CREATE TABLE AS',
    COPY_STMT => 'COPY',
    DELETE_STMT => 'DELETE FROM',
    DROP_STMT => 'DROP',
    EXPLAIN_STMT => 'EXPLAIN',
    LOCK_STMT => 'LOCK',
    TRANSACTION_STMT => 'TRANSACTION',
    TRUNCATE_STMT => 'TRUNCATE',
    VACUUM_STMT => 'VACUUM',
    VARIABLE_SET_STMT => 'SET',
    VARIABLE_SHOW_STMT => 'SHOW'
    # All others default to simply upper-casing the input name
  }

  LEGACY_A_EXPR_NAMES = [
    'AEXPR',
    'AEXPR AND'
    # FIXME
  ]

  def transform_parsetree_a_const(node)
    type_key = node[A_CONST]['val'].keys[0]

    case type_key
    when INTEGER
      node[A_CONST]['type'] = 'integer'
      node[A_CONST]['val'] = node[A_CONST]['val'][INTEGER]['ival']
    when STRING
      node[A_CONST]['type'] = 'integer'
      node[A_CONST]['val'] = node[A_CONST]['val'][STRING]['ival']
    when FLOAT
      node[A_CONST]['type'] = 'float'
      node[A_CONST]['val'] = node[A_CONST]['val'][FLOAT]['str'].to_f
    when BIT_STRING
      node[A_CONST]['type'] = 'bitstring'
      node[A_CONST]['val'] = node[A_CONST]['val'][BIT_STRING]['str']
    else
      puts node
      puts type_key
      fail ArgumentError
      # ...
    end
  end

  def transform_string_list(list)
    return if list.nil?

    list.map! { |node| node.keys[0] == STRING ? node[STRING]['str'] : node }
  end
end
