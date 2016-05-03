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
        node[CONSTRAINT]['contype'] = LEGACY_CONSTRAINT_TYPES[node[CONSTRAINT]['contype']]
        transform_string_list(node[CONSTRAINT]['keys'])
      when COPY_STMT
        transform_string_list(node[COPY_STMT]['attlist'])
      when DEF_ELEM
        node[DEF_ELEM]['arg'] = node[DEF_ELEM]['arg'][INTEGER]['ival'] if node[DEF_ELEM]['arg'].is_a?(Hash) && node[DEF_ELEM]['arg'].keys[0] == INTEGER
        node[DEF_ELEM]['arg'] = node[DEF_ELEM]['arg'][STRING]['str'] if node[DEF_ELEM]['arg'].is_a?(Hash) && node[DEF_ELEM]['arg'].keys[0] == STRING
        transform_string_list(node[DEF_ELEM]['arg']) if node[DEF_ELEM]['arg'].is_a?(Array)
      when DROP_STMT
        node[DROP_STMT]['objects'].each { |obj| transform_string_list(obj) }
      when FUNC_CALL
        transform_string_list(node[FUNC_CALL]['funcname'])
      when GRANT_ROLE_STMT
        transform_string_list(node[GRANT_ROLE_STMT]['grantee_roles'])
      when TYPE_NAME
        transform_string_list(node[TYPE_NAME]['names'])
      end

      node[new_key] = node.delete(key)
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
    INSERT_STMT => 'INSERT INTO',
    EXPLAIN_STMT => 'EXPLAIN',
    LOCK_STMT => 'LOCK',
    TRANSACTION_STMT => 'TRANSACTION',
    TRUNCATE_STMT => 'TRUNCATE',
    UPDATE_STMT => 'UPDATE',
    VACUUM_STMT => 'VACUUM',
    VARIABLE_SET_STMT => 'SET',
    VARIABLE_SHOW_STMT => 'SHOW'
    # All others default to simply upper-casing the input name
  }.freeze

  LEGACY_A_EXPR_NAMES = {
    AEXPR_OP => 'AEXPR',
    # AEXPR_OP_ANY = 1           # normal operator
    # AEXPR_OP_ALL = 2           # scalar op ALL (array)
    # AEXPR_DISTINCT = 3         # IS DISTINCT FROM - name must be "="
    # AEXPR_NULLIF = 4           # NULLIF - name must be "="
    # AEXPR_OF = 5               # IS [NOT] OF - name must be "=" or "<>"
    # AEXPR_IN = 6               # [NOT] IN - name must be "=" or "<>"
    # AEXPR_LIKE = 7             # [NOT] LIKE - name must be "~~" or "!~~"
    # AEXPR_ILIKE = 8            # [NOT] ILIKE - name must be "~~*" or "!~~*"
    AEXPR_SIMILAR => 'AEXPR',
    # AEXPR_BETWEEN = 10         # name must be "BETWEEN"
    # AEXPR_NOT_BETWEEN = 11     # name must be "NOT BETWEEN"
    # AEXPR_BETWEEN_SYM = 12     # name must be "BETWEEN SYMMETRIC"
    # AEXPR_NOT_BETWEEN_SYM = 13 # name must be "NOT BETWEEN SYMMETRIC"
    # AEXPR_PAREN = 14           # nameless dummy node for parentheses
  }.freeze

  LEGACY_CONSTRAINT_TYPES = {
    # CONSTR_TYPE_NULL = 0 # not standard SQL, but a lot of people expect it
    # CONSTR_TYPE_NOTNULL = 1
    # CONSTR_TYPE_DEFAULT = 2
    # CONSTR_TYPE_CHECK = 3
    CONSTR_TYPE_PRIMARY => 'PRIMARY_KEY',
    # CONSTR_TYPE_UNIQUE = 5
    # CONSTR_TYPE_EXCLUSION = 6
    # CONSTR_TYPE_FOREIGN = 7
    # CONSTR_TYPE_ATTR_DEFERRABLE = 8 # attributes for previous constraint node
    # CONSTR_TYPE_ATTR_NOT_DEFERRABLE = 9
    # CONSTR_TYPE_ATTR_DEFERRED = 10
    # CONSTR_TYPE_ATTR_IMMEDIATE = 11
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

    list.map! { |node| node.keys[0] == STRING ? node[STRING]['str'] : node }
  end
end
