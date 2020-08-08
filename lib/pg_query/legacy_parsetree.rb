class PgQuery::ParseResult
  # Legacy parsetree from 0.7 and earlier versions - migrate to "tree" format if you can
  def parsetree # rubocop:disable Metrics/CyclomaticComplexity
    @parsetree ||= transform_nodes!(@tree) do |raw_node|
      node = raw_node.keys[0] == RAW_STMT ? raw_node.delete(RAW_STMT)[STMT_FIELD] : raw_node

      key = node.keys[0]
      new_key = LEGACY_NODE_NAMES[key] || key.upcase

      case key
      when A_CONST
        transform_parsetree_a_const(node)
      when A_EXPR
        node[A_EXPR]['name'] = transform_string_list(node[A_EXPR]['name'])
        node[key].delete('kind')
      when COLUMN_REF
        node[COLUMN_REF]['fields'] = transform_string_list(node[COLUMN_REF]['fields'])
      when CREATE_FUNCTION_STMT
        node[CREATE_FUNCTION_STMT]['funcname'] = transform_string_list(node[CREATE_FUNCTION_STMT]['funcname'])
      when CREATE_TRIG_STMT
        node[CREATE_TRIG_STMT]['funcname'] = transform_string_list(node[CREATE_TRIG_STMT]['funcname'])
      when CONSTRAINT
        node[CONSTRAINT]['contype'] = LEGACY_CONSTRAINT_TYPES[node[CONSTRAINT]['contype']]
        node[CONSTRAINT]['keys'] = transform_string_list(node[CONSTRAINT]['keys'])
      when COPY_STMT
        node[COPY_STMT]['attlist'] = transform_string_list(node[COPY_STMT]['attlist'])
      when DEF_ELEM
        node[DEF_ELEM]['arg'] = node[DEF_ELEM]['arg'][INTEGER]['ival'] if node[DEF_ELEM]['arg'].is_a?(Hash) && node[DEF_ELEM]['arg'].keys[0] == INTEGER
        node[DEF_ELEM]['arg'] = node[DEF_ELEM]['arg'][STRING]['str'] if node[DEF_ELEM]['arg'].is_a?(Hash) && node[DEF_ELEM]['arg'].keys[0] == STRING
        node[DEF_ELEM]['arg'] = transform_string_list(node[DEF_ELEM]['arg']) if node[DEF_ELEM]['arg'].is_a?(Array)
      when DROP_STMT
        node[DROP_STMT]['objects'].each_with_index do |obj, idx|
          node[DROP_STMT]['objects'][idx] = transform_string_list(obj)
        end
      when FUNC_CALL
        node[FUNC_CALL]['funcname'] = transform_string_list(node[FUNC_CALL]['funcname'])
      when GRANT_ROLE_STMT
        node[GRANT_ROLE_STMT]['grantee_roles'] = transform_string_list(node[GRANT_ROLE_STMT]['grantee_roles'])
      when RANGE_VAR
        node[RANGE_VAR]['inhOpt'] = node[RANGE_VAR].delete('inh') ? 2 : 0
      when TYPE_NAME
        node[TYPE_NAME]['names'] = transform_string_list(node[TYPE_NAME]['names'])
      end

      raw_node[new_key] = node.delete(key)
    end
  end

  private

  LEGACY_NODE_NAMES = {
    PgQuery::A_EXPR => 'AEXPR',
    PgQuery::SELECT_STMT => 'SELECT',
    PgQuery::ALTER_TABLE_CMD => 'ALTER TABLE CMD',
    PgQuery::ALTER_TABLE_STMT => 'ALTER TABLE',
    PgQuery::CHECK_POINT_STMT => 'CHECKPOINT',
    PgQuery::CREATE_SCHEMA_STMT => 'CREATE SCHEMA',
    PgQuery::CREATE_TABLE_AS_STMT => 'CREATE TABLE AS',
    PgQuery::COPY_STMT => 'COPY',
    PgQuery::DELETE_STMT => 'DELETE FROM',
    PgQuery::DROP_STMT => 'DROP',
    PgQuery::INSERT_STMT => 'INSERT INTO',
    PgQuery::EXPLAIN_STMT => 'EXPLAIN',
    PgQuery::LOCK_STMT => 'LOCK',
    PgQuery::TRANSACTION_STMT => 'TRANSACTION',
    PgQuery::TRUNCATE_STMT => 'TRUNCATE',
    PgQuery::UPDATE_STMT => 'UPDATE',
    PgQuery::VACUUM_STMT => 'VACUUM',
    PgQuery::VARIABLE_SET_STMT => 'SET',
    PgQuery::VARIABLE_SHOW_STMT => 'SHOW'
    # All others default to simply upper-casing the input name
  }.freeze

  LEGACY_CONSTRAINT_TYPES = {
    PgQuery::CONSTR_TYPE_PRIMARY => 'PRIMARY_KEY'
  }.freeze

  def transform_parsetree_a_const(node)
    type_key = node[A_CONST]['val'].keys[0]

    case type_key
    when INTEGER
      node[A_CONST]['type'] = 'integer'
      node[A_CONST]['val'] = node[A_CONST]['val'][INTEGER]['ival']
    when STRING
      node[A_CONST]['type'] = 'string'
      node[A_CONST]['val'] = node[A_CONST]['val'][STRING]['str']
    when FLOAT
      node[A_CONST]['type'] = 'float'
      node[A_CONST]['val'] = node[A_CONST]['val'][FLOAT]['str'].to_f
    when BIT_STRING
      node[A_CONST]['type'] = 'bitstring'
      node[A_CONST]['val'] = node[A_CONST]['val'][BIT_STRING]['str']
    when NULL
      node[A_CONST]['type'] = 'null'
      node[A_CONST]['val'] = nil
    end
  end

  def transform_string_list(list)
    return if list.nil?

    if list.is_a?(Array)
      list.map { |node| node.keys[0] == STRING ? node[STRING]['str'] : node }
    else
      [list.keys[0] == STRING ? list[STRING]['str'] : list]
    end
  end
end
