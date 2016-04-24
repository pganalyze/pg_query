# rubocop:disable Style/ConstantName
class PgQuery
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
  COALESCE_EXPR = 'CoalesceExpr'.freeze
  COLUMN_DEF = 'ColumnDef'.freeze
  COLUMN_REF = 'ColumnRef'.freeze
  COMMON_TABLE_EXPR = 'CommonTableExpr'.freeze
  CONSTRAINT = 'Constraint'.freeze
  COPY_STMT = 'CopyStmt'.freeze
  CREATE_FUNCTION_STMT = 'CreateFunctionStmt'.freeze
  CREATE_SCHEMA_STMT = 'CreateSchemaStmt'.freeze
  CREATE_STMT = 'CreateStmt'.freeze
  CREATE_TABLE_AS_STMT = 'CreateTableAsStmt'.freeze
  CREATE_TRIG_STMT = 'CreateTrigStmt'.freeze
  DEF_ELEM = 'DefElem'.freeze
  DELETE_STMT = 'DeleteStmt'.freeze
  DROP_STMT = 'DropStmt'.freeze
  EXPLAIN_STMT = 'ExplainStmt'.freeze
  FLOAT = 'Float'.freeze
  FUNC_CALL = 'FuncCall'.freeze
  FUNCTION_PARAMETER = 'FunctionParameter'.freeze
  GRANT_STMT = 'GrantStmt'.freeze
  GRANT_ROLE_STMT = 'GrantRoleStmt'.freeze
  INDEX_ELEM = 'IndexElem'.freeze
  INDEX_STMT = 'IndexStmt'.freeze
  INSERT_STMT = 'InsertStmt'.freeze
  INTO_CLAUSE = 'IntoClause'.freeze
  JOIN_EXPR = 'JoinExpr'.freeze
  LOCK_STMT = 'LockStmt'.freeze
  LOCKING_CLAUSE = 'LockingClause'.freeze
  NULL_TEST = 'NullTest'.freeze
  RANGE_FUNCTION = 'RangeFunction'.freeze
  PARAM_REF = 'ParamRef'.freeze
  RANGE_SUBSELECT = 'RangeSubselect'.freeze
  RANGE_VAR = 'RangeVar'.freeze
  REFRESH_MAT_VIEW_STMT = 'RefreshMatViewStmt'.freeze
  RENAME_STMT = 'RenameStmt'.freeze
  RES_TARGET = 'ResTarget'.freeze
  ROW_EXPR = 'RowExpr'.freeze
  RULE_STMT = 'RuleStmt'.freeze
  ROLE_SPEC = 'RoleSpec'.freeze
  SELECT_STMT = 'SelectStmt'.freeze
  SORT_BY = 'SortBy'.freeze
  SUB_LINK = 'SubLink'.freeze
  TRANSACTION_STMT = 'TransactionStmt'.freeze
  TRUNCATE_STMT = 'TruncateStmt'.freeze
  TYPE_CAST = 'TypeCast'.freeze
  TYPE_NAME = 'TypeName'.freeze
  UPDATE_STMT = 'UpdateStmt'.freeze
  VACUUM_STMT = 'VacuumStmt'.freeze
  VARIABLE_SET_STMT = 'VariableSetStmt'.freeze
  VARIABLE_SHOW_STMT = 'VariableShowStmt'.freeze
  VIEW_STMT = 'ViewStmt'.freeze
  WINDOW_DEF = 'WindowDef'.freeze
  WITH_CLAUSE = 'WithClause'.freeze
  STRING = 'String'.freeze
  INTEGER = 'Integer'.freeze
  SET_TO_DEFAULT = 'SetToDefault'.freeze
  PREPARE_STMT = 'PrepareStmt'.freeze
  EXECUTE_STMT = 'ExecuteStmt'.freeze
  DEALLOCATE_STMT = 'DeallocateStmt'.freeze
  NULL = 'Null'.freeze
  INT_LIST = 'IntList'.freeze
  OID_LIST = 'OidList'.freeze

  # FIELDS

  FROM_CLAUSE_FIELD = 'fromClause'.freeze
  TARGET_LIST_FIELD = 'targetList'.freeze
  COLS_FIELD = 'cols'.freeze
  REXPR_FIELD = 'rexpr'.freeze

  # ENUMS

  CONSTR_TYPE_NULL = 0 # not standard SQL, but a lot of people expect it
  CONSTR_TYPE_NOTNULL = 1
  CONSTR_TYPE_DEFAULT = 2
  CONSTR_TYPE_CHECK = 3
  CONSTR_TYPE_PRIMARY = 4
  CONSTR_TYPE_UNIQUE = 5
  CONSTR_TYPE_EXCLUSION = 6
  CONSTR_TYPE_FOREIGN = 7
  CONSTR_TYPE_ATTR_DEFERRABLE = 8 # attributes for previous constraint node
  CONSTR_TYPE_ATTR_NOT_DEFERRABLE = 9
  CONSTR_TYPE_ATTR_DEFERRED = 10
  CONSTR_TYPE_ATTR_IMMEDIATE = 11

  OBJECT_TYPE_INDEX = 19
  OBJECT_TYPE_RULE = 28
  OBJECT_TYPE_SCHEMA = 29
  OBJECT_TYPE_TABLE = 32
  OBJECT_TYPE_TRIGGER = 35
  OBJECT_TYPE_VIEW = 42

  BOOL_EXPR_AND = 0
  BOOL_EXPR_OR = 1
  BOOL_EXPR_NOT = 2

  AEXPR_OP = 0               # normal operator
  AEXPR_OP_ANY = 1           # scalar op ANY (array)
  AEXPR_OP_ALL = 2           # scalar op ALL (array)
  AEXPR_DISTINCT = 3         # IS DISTINCT FROM - name must be "="
  AEXPR_NULLIF = 4           # NULLIF - name must be "="
  AEXPR_OF = 5               # IS [NOT] OF - name must be "=" or "<>"
  AEXPR_IN = 6               # [NOT] IN - name must be "=" or "<>"
  AEXPR_LIKE = 7             # [NOT] LIKE - name must be "~~" or "!~~"
  AEXPR_ILIKE = 8            # [NOT] ILIKE - name must be "~~*" or "!~~*"
  AEXPR_SIMILAR = 9          # [NOT] SIMILAR - name must be "~" or "!~"
  AEXPR_BETWEEN = 10         # name must be "BETWEEN"
  AEXPR_NOT_BETWEEN = 11     # name must be "NOT BETWEEN"
  AEXPR_BETWEEN_SYM = 12     # name must be "BETWEEN SYMMETRIC"
  AEXPR_NOT_BETWEEN_SYM = 13 # name must be "NOT BETWEEN SYMMETRIC"
  AEXPR_PAREN = 14           # nameless dummy node for parentheses

  TRANS_STMT_BEGIN = 0
  TRANS_STMT_START = 1 # semantically identical to BEGIN
  TRANS_STMT_COMMIT = 2
  TRANS_STMT_ROLLBACK = 3
  TRANS_STMT_SAVEPOINT = 4
  TRANS_STMT_RELEASE = 5
  TRANS_STMT_ROLLBACK_TO = 6
  TRANS_STMT_PREPARE = 7
  TRANS_STMT_COMMIT_PREPARED = 8
  TRANS_STMT_ROLLBACK_PREPARED = 9

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

  AT_AddColumn = 0                  # add column
  AT_AddColumnRecurse = 1           # internal to commands/tablecmds.c
  AT_AddColumnToView = 2            # implicitly via CREATE OR REPLACE VIEW
  AT_ColumnDefault = 3              # alter column default
  AT_DropNotNull = 4                # alter column drop not null
  AT_SetNotNull = 5                 # alter column set not null
  AT_SetStatistics = 6              # alter column set statistics
  AT_SetOptions = 7                 # alter column set ( options )
  AT_ResetOptions = 8               # alter column reset ( options )
  AT_SetStorage = 9                 # alter column set storage
  AT_DropColumn = 10                # drop column
  AT_DropColumnRecurse = 11         # internal to commands/tablecmds.c
  AT_AddIndex = 12                  # add index
  AT_ReAddIndex = 13                # internal to commands/tablecmds.c
  AT_AddConstraint = 14             # add constraint
  AT_AddConstraintRecurse = 15      # internal to commands/tablecmds.c
  AT_ReAddConstraint = 16           # internal to commands/tablecmds.c
  AT_AlterConstraint = 17           # alter constraint
  AT_ValidateConstraint = 18        # validate constraint
  AT_ValidateConstraintRecurse = 19 # internal to commands/tablecmds.c
  AT_ProcessedConstraint = 20       # pre-processed add constraint (local in parser/parse_utilcmd.c)
  AT_AddIndexConstraint = 21        # add constraint using existing index
  AT_DropConstraint = 22            # drop constraint
  AT_DropConstraintRecurse = 23     # internal to commands/tablecmds.c
  AT_ReAddComment = 24              # internal to commands/tablecmds.c
  AT_AlterColumnType = 25           # alter column type
  AT_AlterColumnGenericOptions = 26 # alter column OPTIONS (...)
  AT_ChangeOwner = 27               # change owner
  AT_ClusterOn = 28                 # CLUSTER ON
  AT_DropCluster = 29               # SET WITHOUT CLUSTER
  AT_SetLogged = 30                 # SET LOGGED
  AT_SetUnLogged = 31               # SET UNLOGGED
  AT_AddOids = 32                   # SET WITH OIDS
  AT_AddOidsRecurse = 33            # internal to commands/tablecmds.c
  AT_DropOids = 34                  # SET WITHOUT OIDS
  AT_SetTableSpace = 35             # SET TABLESPACE
  AT_SetRelOptions = 36             # SET (...) -- AM specific parameters
  AT_ResetRelOptions = 37           # RESET (...) -- AM specific parameters
  AT_ReplaceRelOptions = 38         # replace reloption list in its entirety
  AT_EnableTrig = 39                # ENABLE TRIGGER name
  AT_EnableAlwaysTrig = 40          # ENABLE ALWAYS TRIGGER name
  AT_EnableReplicaTrig = 41         # ENABLE REPLICA TRIGGER name
  AT_DisableTrig = 42               # DISABLE TRIGGER name
  AT_EnableTrigAll = 43             # ENABLE TRIGGER ALL
  AT_DisableTrigAll = 44            #  DISABLE TRIGGER ALL
  AT_EnableTrigUser = 45            # ENABLE TRIGGER USER
  AT_DisableTrigUser = 46           # DISABLE TRIGGER USER
  AT_EnableRule = 47                # ENABLE RULE name
  AT_EnableAlwaysRule = 48          # ENABLE ALWAYS RULE name
  AT_EnableReplicaRule = 49         # ENABLE REPLICA RULE name
  AT_DisableRule = 50               # DISABLE RULE name
  AT_AddInherit = 51                # INHERIT parent
  AT_DropInherit = 52               # NO INHERIT parent
  AT_AddOf = 53                     # OF <type_name>
  AT_DropOf = 54                    # NOT OF
  AT_ReplicaIdentity = 55           # REPLICA IDENTITY
  AT_EnableRowSecurity = 56         # ENABLE ROW SECURITY
  AT_DisableRowSecurity = 57        # DISABLE ROW SECURITY
  AT_ForceRowSecurity = 58          # FORCE ROW SECURITY
  AT_NoForceRowSecurity = 59        # NO FORCE ROW SECURITY
  AT_GenericOptions = 60            # OPTIONS (...)
end
