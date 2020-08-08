# rubocop:disable Style/ConstantName
module PgQuery
  # NODE TYPES

  A_ARRAY_EXPR = 'A_ArrayExpr'.freeze
  A_CONST = 'A_Const'.freeze
  A_EXPR = 'A_Expr'.freeze
  A_INDICES = 'A_Indices'.freeze
  A_INDIRECTION = 'A_Indirection'.freeze
  A_STAR = 'A_Star'.freeze
  ACCESS_PRIV = 'AccessPriv'.freeze
  ALIAS = 'Alias'.freeze
  ALTER_TABLE_CMD = 'AlterTableCmd'.freeze
  ALTER_TABLE_STMT = 'AlterTableStmt'.freeze
  BIT_STRING = 'BitString'.freeze
  BOOL_EXPR = 'BoolExpr'.freeze
  BOOLEAN_TEST = 'BooleanTest'.freeze
  CASE_EXPR = 'CaseExpr'.freeze
  CASE_WHEN = 'CaseWhen'.freeze
  CHECK_POINT_STMT = 'CheckPointStmt'.freeze
  CLOSE_PORTAL_STMT = 'ClosePortalStmt'.freeze
  COALESCE_EXPR = 'CoalesceExpr'.freeze
  COLLATE_CLAUSE = 'CollateClause'.freeze
  COLUMN_DEF = 'ColumnDef'.freeze
  COLUMN_REF = 'ColumnRef'.freeze
  COMMON_TABLE_EXPR = 'CommonTableExpr'.freeze
  COMPOSITE_TYPE_STMT = 'CompositeTypeStmt'.freeze
  CONSTRAINT = 'Constraint'.freeze
  COPY_STMT = 'CopyStmt'.freeze
  CREATE_CAST_STMT = 'CreateCastStmt'.freeze
  CREATE_DOMAIN_STMT = 'CreateDomainStmt'.freeze
  CREATE_ENUM_STMT = 'CreateEnumStmt'.freeze
  CREATE_FUNCTION_STMT = 'CreateFunctionStmt'.freeze
  CREATE_RANGE_STMT = 'CreateRangeStmt'.freeze
  CREATE_SCHEMA_STMT = 'CreateSchemaStmt'.freeze
  CREATE_STMT = 'CreateStmt'.freeze
  CREATE_TABLE_AS_STMT = 'CreateTableAsStmt'.freeze
  CREATE_TRIG_STMT = 'CreateTrigStmt'.freeze
  DEALLOCATE_STMT = 'DeallocateStmt'.freeze
  DECLARE_CURSOR_STMT = 'DeclareCursorStmt'.freeze
  DEF_ELEM = 'DefElem'.freeze
  DEFINE_STMT = 'DefineStmt'.freeze
  DELETE_STMT = 'DeleteStmt'.freeze
  DISCARD_STMT = 'DiscardStmt'.freeze
  DO_STMT = 'DoStmt'.freeze
  DROP_STMT = 'DropStmt'.freeze
  DROP_SUBSCRIPTION = 'DropSubscriptionStmt'.freeze
  DROP_TABLESPACE = 'DropTableSpaceStmt'.freeze
  DROP_ROLE = 'DropRoleStmt'.freeze
  EXECUTE_STMT = 'ExecuteStmt'.freeze
  EXPLAIN_STMT = 'ExplainStmt'.freeze
  FETCH_STMT = 'FetchStmt'.freeze
  FLOAT = 'Float'.freeze
  FUNC_CALL = 'FuncCall'.freeze
  FUNCTION_PARAMETER = 'FunctionParameter'.freeze
  GRANT_ROLE_STMT = 'GrantRoleStmt'.freeze
  GRANT_STMT = 'GrantStmt'.freeze
  INDEX_ELEM = 'IndexElem'.freeze
  INDEX_STMT = 'IndexStmt'.freeze
  INSERT_STMT = 'InsertStmt'.freeze
  INT_LIST = 'IntList'.freeze
  INTEGER = 'Integer'.freeze
  INTO_CLAUSE = 'IntoClause'.freeze
  JOIN_EXPR = 'JoinExpr'.freeze
  LOCK_STMT = 'LockStmt'.freeze
  LOCKING_CLAUSE = 'LockingClause'.freeze
  NULL = 'Null'.freeze
  NULL_TEST = 'NullTest'.freeze
  OBJECT_WITH_ARGS = 'ObjectWithArgs'.freeze
  OID_LIST = 'OidList'.freeze
  ON_CONFLICT_CLAUSE = 'OnConflictClause'.freeze
  PARAM_REF = 'ParamRef'.freeze
  PREPARE_STMT = 'PrepareStmt'.freeze
  RANGE_FUNCTION = 'RangeFunction'.freeze
  RANGE_SUBSELECT = 'RangeSubselect'.freeze
  RANGE_VAR = 'RangeVar'.freeze
  RAW_STMT = 'RawStmt'.freeze
  REFRESH_MAT_VIEW_STMT = 'RefreshMatViewStmt'.freeze
  RENAME_STMT = 'RenameStmt'.freeze
  RES_TARGET = 'ResTarget'.freeze
  ROLE_SPEC = 'RoleSpec'.freeze
  ROW_EXPR = 'RowExpr'.freeze
  RULE_STMT = 'RuleStmt'.freeze
  SELECT_STMT = 'SelectStmt'.freeze
  SET_TO_DEFAULT = 'SetToDefault'.freeze
  SORT_BY = 'SortBy'.freeze
  SQL_VALUE_FUNCTION = 'SQLValueFunction'.freeze
  STRING = 'String'.freeze
  SUB_LINK = 'SubLink'.freeze
  TRANSACTION_STMT = 'TransactionStmt'.freeze
  TRUNCATE_STMT = 'TruncateStmt'.freeze
  TYPE_CAST = 'TypeCast'.freeze
  TYPE_NAME = 'TypeName'.freeze
  UPDATE_STMT = 'UpdateStmt'.freeze
  VACUUM_RELATION = 'VacuumRelation'.freeze
  VACUUM_STMT = 'VacuumStmt'.freeze
  VARIABLE_SET_STMT = 'VariableSetStmt'.freeze
  VARIABLE_SHOW_STMT = 'VariableShowStmt'.freeze
  VIEW_STMT = 'ViewStmt'.freeze
  WINDOW_DEF = 'WindowDef'.freeze
  WITH_CLAUSE = 'WithClause'.freeze

  # FIELDS

  COLS_FIELD = 'cols'.freeze
  FROM_CLAUSE_FIELD = 'fromClause'.freeze
  RELPERSISTENCE_FIELD = 'relpersistence'.freeze
  REXPR_FIELD = 'rexpr'.freeze
  STMT_FIELD = 'stmt'.freeze
  TARGET_LIST_FIELD = 'targetList'.freeze
  VALUES_LISTS_FIELD = 'valuesLists'.freeze

  # ENUMS

  BOOL_EXPR_AND = 0
  BOOL_EXPR_OR = 1
  BOOL_EXPR_NOT = 2

  BOOLEAN_TEST_TRUE = 0
  BOOLEAN_TEST_NOT_TRUE = 1
  BOOLEAN_TEST_FALSE = 2
  BOOLEAN_TEST_NOT_FALSE = 3
  BOOLEAN_TEST_UNKNOWN = 4
  BOOLEAN_TEST_NOT_UNKNOWN = 5

  SUBLINK_TYPE_EXISTS = 0     # EXISTS(SELECT ...)
  SUBLINK_TYPE_ALL = 1        # (lefthand) op ALL (SELECT ...)
  SUBLINK_TYPE_ANY = 2        # (lefthand) op ANY (SELECT ...)
  SUBLINK_TYPE_ROWCOMPARE = 3 # (lefthand) op (SELECT ...)
  SUBLINK_TYPE_EXPR = 4       # (SELECT with single targetlist item ...)
  SUBLINK_TYPE_MULTIEXPR = 5  # (SELECT with multiple targetlist items ...)
  SUBLINK_TYPE_ARRAY = 6      # ARRAY(SELECT with single targetlist item ...)
  SUBLINK_TYPE_CTE = 7        # WITH query (never actually part of an expression), for SubPlans only

  LCS_NONE = 0           # no such clause - only used in PlanRowMark
  LCS_FORKEYSHARE = 1    # FOR KEY SHARE
  LCS_FORSHARE = 2       # FOR SHARE
  LCS_FORNOKEYUPDATE = 3 # FOR NO KEY UPDATE
  LCS_FORUPDATE = 4      # FOR UPDATE
end

JSON.parse(File.read(File.dirname(__FILE__) + '/enum_defs.json'))['nodes/parsenodes']['ConstrType']['values'].map { |v| v['name'] }.compact.each_with_index do |v, idx|
  PgQuery.const_set(v.sub('CONSTR_', 'CONSTR_TYPE_'), idx)
end

JSON.parse(File.read(File.dirname(__FILE__) + '/enum_defs.json'))['nodes/parsenodes']['ObjectType']['values'].map { |v| v['name'] }.compact.each_with_index do |v, idx|
  PgQuery.const_set(v.sub('OBJECT_', 'OBJECT_TYPE_'), idx)
end

JSON.parse(File.read(File.dirname(__FILE__) + '/enum_defs.json'))['nodes/parsenodes']['AlterTableType']['values'].map { |v| v['name'] }.compact.each_with_index do |v, idx|
  PgQuery.const_set(v, idx)
end

JSON.parse(File.read(File.dirname(__FILE__) + '/enum_defs.json'))['nodes/parsenodes']['A_Expr_Kind']['values'].map { |v| v['name'] }.compact.each_with_index do |v, idx|
  PgQuery.const_set(v, idx)
end

JSON.parse(File.read(File.dirname(__FILE__) + '/enum_defs.json'))['nodes/parsenodes']['TransactionStmtKind']['values'].map { |v| v['name'] }.compact.each_with_index do |v, idx|
  PgQuery.const_set(v, idx)
end