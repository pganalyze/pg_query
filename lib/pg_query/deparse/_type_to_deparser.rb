# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
module PgQuery::Deparse
  extend self

  # Note: This is not a module-level const to avoid having a strict loading order
  def type_to_deparser(type)
    {
      'A_ARRAYEXPR' => A_ARRAYEXPR,
      'A_CONST' => A_CONST,
      'A_INDICES' => A_INDICES,
      'A_INDIRECTION' => A_INDIRECTION,
      'A_STAR' => A_STAR,
      'A_TRUNCATED' => A_TRUNCATED,
      'AEXPR' => AEXPR,
      'AEXPR AND' => AEXPR_AND,
      'AEXPR ANY' => AEXPR_ANY,
      'AEXPR IN' => AEXPR_IN,
      'AEXPR NOT' => AEXPR_NOT,
      'AEXPR OR' => AEXPR_OR,
      'ALIAS' => ALIAS,
      'ALTER TABLE' => ALTER_TABLE,
      'ALTER TABLE CMD' => ALTER_TABLE_CMD,
      'CASE' => CASE,
      'COALESCE' => COALESCE,
      'COLUMNDEF' => COLUMNDEF,
      'COLUMNREF' => COLUMNREF,
      'COMMONTABLEEXPR' => COMMONTABLEEXPR,
      'CONSTRAINT' => CONSTRAINT,
      'CREATESTMT' => CREATESTMT,
      'CREATEFUNCTIONSTMT' => CREATEFUNCTIONSTMT,
      'DEFELEM' => DEFELEM,
      'DELETE FROM' => DELETE_FROM,
      'DROP' => DROP,
      'FUNCCALL' => FUNCCALL,
      'FUNCTIONPARAMETER' => FUNCTIONPARAMETER,
      'INSERT INTO' => INSERT_INTO,
      'JOINEXPR' => JOINEXPR,
      'LOCKINGCLAUSE' => LOCKINGCLAUSE,
      'NULLTEST' => NULLTEST,
      'PARAMREF' => PARAMREF,
      'RANGEFUNCTION' => RANGEFUNCTION,
      'RANGESUBSELECT' => RANGESUBSELECT,
      'RANGEVAR' => RANGEVAR,
      'RENAMESTMT' => RENAMESTMT,
      'RESTARGET' => RESTARGET,
      'ROW' => ROW,
      'SELECT' => SELECT,
      'SORTBY' => SORTBY,
      'SUBLINK' => SUBLINK,
      'TRANSACTION' => TRANSACTION,
      'TYPECAST' => TYPECAST,
      'TYPENAME' => TYPENAME,
      'UPDATE' => UPDATE,
      'VIEWSTMT' => VIEWSTMT,
      'WHEN' => WHEN,
      'WINDOWDEF' => WINDOWDEF,
      'WITHCLAUSE' => WITHCLAUSE,
    }[type]
  end
end
