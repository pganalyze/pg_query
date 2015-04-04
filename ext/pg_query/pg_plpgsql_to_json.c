#include "pg_query.h"
#include "pg_plpgsql_to_json.h"

#include "lib/stringinfo.h"

#define WRITE_INT_FIELD(fldname, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": %d, ", value)

#define WRITE_UINT_FIELD(fldname, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": %u, ", value)

/* Write an OID field (don't hard-wire assumption that OID is same as uint) */
#define WRITE_OID_FIELD(fldname, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": %u, ", value)

#define WRITE_LONG_FIELD(fldname, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": %ld, ", value)

/* Write a char field (ie, one ascii character) */
#define WRITE_CHAR_FIELD(fldname, value) \
  if (node->fldname == 0) { appendStringInfo(str, "\"" CppAsString(fldname) "\": null, "); \
  } else { appendStringInfo(str, "\"" CppAsString(fldname) "\": \"%c\", ", value); }

/* Write an enumerated-type field as an integer code */
#define WRITE_ENUM_FIELD(fldname, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": %d, ", \
					 (int) value)

/* Write a float field --- caller must give format to define precision */
#define WRITE_FLOAT_FIELD(fldname, format, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": " format ", ", value)

/* Write a boolean field */
#define WRITE_BOOL_FIELD(fldname, value) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": %s, ", \
					 booltostr(value))

/* Write a character-string (possibly NULL) field */
#define WRITE_STRING_FIELD(fldname, value) \
	(appendStringInfo(str, "\"" CppAsString(fldname) "\": "), \
	 _outToken(str, value), \
	 appendStringInfo(str, ", "))

#define WRITE_NULL_FIELD(fldname) \
	appendStringInfo(str, "\"" CppAsString(fldname) "\": null, ")

#define booltostr(x)  ((x) ? "true" : "false")

/*
* _outToken
*	  Convert an ordinary string (eg, an identifier) into a form that
*	  will be decoded back to a plain token by read.c's functions.
*
*	  If a null or empty string is given, it is encoded as "<>".
*/
static void
_outToken(StringInfo str, const char *s)
{
	if (s == NULL || *s == '\0')
	{
		appendStringInfoString(str, "null");
		return;
	}

	appendStringInfoChar(str, '"');
	while (*s)
	{
		/* These chars must be backslashed anywhere in the string */
		if (*s == '\n')
			appendStringInfoString(str, "\\n");
		else if (*s == '\r')
			appendStringInfoString(str, "\\r");
		else if (*s == '\t')
			appendStringInfoString(str, "\\t");
		else if (*s == '\\' || *s == '"') {
			appendStringInfoChar(str, '\\');
			appendStringInfoChar(str, *s);
		} else
			appendStringInfoChar(str, *s);
		s++;
	}
	appendStringInfoChar(str, '"');
}

static void
removeTrailingDelimiter(StringInfo str)
{
	if (str->len >= 2 && str->data[str->len - 2] == ',' && str->data[str->len - 1] == ' ') {
		str->len -= 2;
		str->data[str->len] = '\0';
	} else if (str->len >= 1 && str->data[str->len - 1] == ',') {
		str->len -= 1;
		str->data[str->len] = '\0';
	}
}

static void dump_stmt(StringInfo str, PLpgSQL_stmt *stmt);
static void dump_block(StringInfo str, PLpgSQL_stmt_block *block);
static void dump_assign(StringInfo str, PLpgSQL_stmt_assign *stmt);
static void dump_if(StringInfo str, PLpgSQL_stmt_if *stmt);
static void dump_case(StringInfo str, PLpgSQL_stmt_case *stmt);
static void dump_loop(StringInfo str, PLpgSQL_stmt_loop *stmt);
static void dump_while(StringInfo str, PLpgSQL_stmt_while *stmt);
static void dump_fori(StringInfo str, PLpgSQL_stmt_fori *stmt);
static void dump_fors(StringInfo str, PLpgSQL_stmt_fors *stmt);
static void dump_forc(StringInfo str, PLpgSQL_stmt_forc *stmt);
static void dump_foreach_a(StringInfo str, PLpgSQL_stmt_foreach_a *stmt);
static void dump_exit(StringInfo str, PLpgSQL_stmt_exit *stmt);
static void dump_return(StringInfo str, PLpgSQL_stmt_return *stmt);
static void dump_return_next(StringInfo str, PLpgSQL_stmt_return_next *stmt);
static void dump_return_query(StringInfo str, PLpgSQL_stmt_return_query *stmt);
static void dump_raise(StringInfo str, PLpgSQL_stmt_raise *stmt);
static void dump_execsql(StringInfo str, PLpgSQL_stmt_execsql *stmt);
static void dump_dynexecute(StringInfo str, PLpgSQL_stmt_dynexecute *stmt);
static void dump_dynfors(StringInfo str, PLpgSQL_stmt_dynfors *stmt);
static void dump_getdiag(StringInfo str, PLpgSQL_stmt_getdiag *stmt);
static void dump_open(StringInfo str, PLpgSQL_stmt_open *stmt);
static void dump_fetch(StringInfo str, PLpgSQL_stmt_fetch *stmt);
static void dump_cursor_direction(StringInfo str, PLpgSQL_stmt_fetch *stmt);
static void dump_close(StringInfo str, PLpgSQL_stmt_close *stmt);
static void dump_perform(StringInfo str, PLpgSQL_stmt_perform *stmt);
static void dump_expr(StringInfo str, PLpgSQL_expr *expr);
static void dump_function(StringInfo str, PLpgSQL_function *func);

static void
dump_stmt(StringInfo str, PLpgSQL_stmt *stmt)
{

	appendStringInfoChar(str, '{');
	WRITE_INT_FIELD(lineno, stmt->lineno);
	switch ((enum PLpgSQL_stmt_types) stmt->cmd_type)
	{
		case PLPGSQL_STMT_BLOCK:
			dump_block(str, (PLpgSQL_stmt_block *) stmt);
			break;
		case PLPGSQL_STMT_ASSIGN:
			dump_assign(str, (PLpgSQL_stmt_assign *) stmt);
			break;
		case PLPGSQL_STMT_IF:
			dump_if(str, (PLpgSQL_stmt_if *) stmt);
			break;
		case PLPGSQL_STMT_CASE:
			dump_case(str, (PLpgSQL_stmt_case *) stmt);
			break;
		case PLPGSQL_STMT_LOOP:
			dump_loop(str, (PLpgSQL_stmt_loop *) stmt);
			break;
		case PLPGSQL_STMT_WHILE:
			dump_while(str, (PLpgSQL_stmt_while *) stmt);
			break;
		case PLPGSQL_STMT_FORI:
			dump_fori(str, (PLpgSQL_stmt_fori *) stmt);
			break;
		case PLPGSQL_STMT_FORS:
			dump_fors(str, (PLpgSQL_stmt_fors *) stmt);
			break;
		case PLPGSQL_STMT_FORC:
			dump_forc(str, (PLpgSQL_stmt_forc *) stmt);
			break;
		case PLPGSQL_STMT_FOREACH_A:
			dump_foreach_a(str, (PLpgSQL_stmt_foreach_a *) stmt);
			break;
		case PLPGSQL_STMT_EXIT:
			dump_exit(str, (PLpgSQL_stmt_exit *) stmt);
			break;
		case PLPGSQL_STMT_RETURN:
			dump_return(str, (PLpgSQL_stmt_return *) stmt);
			break;
		case PLPGSQL_STMT_RETURN_NEXT:
			dump_return_next(str, (PLpgSQL_stmt_return_next *) stmt);
			break;
		case PLPGSQL_STMT_RETURN_QUERY:
			dump_return_query(str, (PLpgSQL_stmt_return_query *) stmt);
			break;
		case PLPGSQL_STMT_RAISE:
			dump_raise(str, (PLpgSQL_stmt_raise *) stmt);
			break;
		case PLPGSQL_STMT_EXECSQL:
			dump_execsql(str, (PLpgSQL_stmt_execsql *) stmt);
			break;
		case PLPGSQL_STMT_DYNEXECUTE:
			dump_dynexecute(str, (PLpgSQL_stmt_dynexecute *) stmt);
			break;
		case PLPGSQL_STMT_DYNFORS:
			dump_dynfors(str, (PLpgSQL_stmt_dynfors *) stmt);
			break;
		case PLPGSQL_STMT_GETDIAG:
			dump_getdiag(str, (PLpgSQL_stmt_getdiag *) stmt);
			break;
		case PLPGSQL_STMT_OPEN:
			dump_open(str, (PLpgSQL_stmt_open *) stmt);
			break;
		case PLPGSQL_STMT_FETCH:
			dump_fetch(str, (PLpgSQL_stmt_fetch *) stmt);
			break;
		case PLPGSQL_STMT_CLOSE:
			dump_close(str, (PLpgSQL_stmt_close *) stmt);
			break;
		case PLPGSQL_STMT_PERFORM:
			dump_perform(str, (PLpgSQL_stmt_perform *) stmt);
			break;
		default:
			elog(ERROR, "unrecognized cmd_type: %d", stmt->cmd_type);
			break;
	}
	removeTrailingDelimiter(str);
	appendStringInfoString(str, "}, ");
}

static void
dump_stmts(StringInfo str, List *stmts)
{
	ListCell   *s;

	appendStringInfoString(str, "\"statements\": ");
	appendStringInfoChar(str, '[');
	foreach(s, stmts) {
		dump_stmt(str, (PLpgSQL_stmt *) lfirst(s));
	}
	removeTrailingDelimiter(str);
	appendStringInfoString(str, "], ");
}

static void
dump_block(StringInfo str, PLpgSQL_stmt_block *block)
{
	char	   *name;

	if (block->label == NULL)
		name = "*unnamed*";
	else
		name = block->label;

  WRITE_STRING_FIELD(type, "block");
  WRITE_STRING_FIELD(name, name);

	dump_stmts(str, block->body);

	if (block->exceptions)
	{
		ListCell   *e;

		foreach(e, block->exceptions->exc_list)
		{
			PLpgSQL_exception *exc = (PLpgSQL_exception *) lfirst(e);
			PLpgSQL_condition *cond;

			appendStringInfo(str, "    EXCEPTION WHEN ");
			for (cond = exc->conditions; cond; cond = cond->next)
			{
				if (cond != exc->conditions)
					appendStringInfo(str, " OR ");
				appendStringInfo(str, "%s", cond->condname);
			}
			appendStringInfo(str, " THEN");
			dump_stmts(str, exc->action);
		}
	}

	removeTrailingDelimiter(str);
}

static void
dump_assign(StringInfo str, PLpgSQL_stmt_assign *stmt)
{
	WRITE_STRING_FIELD(type, "ASSIGN");
	WRITE_INT_FIELD(varno, stmt->varno);
	dump_expr(str, stmt->expr);
}

static void
dump_if(StringInfo str, PLpgSQL_stmt_if *stmt)
{
	ListCell   *l;

	appendStringInfo(str, "IF ");
	dump_expr(str, stmt->cond);
	appendStringInfo(str, " THEN");
	dump_stmts(str, stmt->then_body);
	foreach(l, stmt->elsif_list)
	{
		PLpgSQL_if_elsif *elif = (PLpgSQL_if_elsif *) lfirst(l);

		appendStringInfo(str, "    ELSIF ");
		dump_expr(str, elif->cond);
		appendStringInfo(str, " THEN");
		dump_stmts(str, elif->stmts);
	}
	if (stmt->else_body != NIL)
	{
		appendStringInfo(str, "    ELSE");
		dump_stmts(str, stmt->else_body);
	}
	appendStringInfo(str, "    ENDIF");
}

static void
dump_case(StringInfo str, PLpgSQL_stmt_case *stmt)
{
	ListCell   *l;

	WRITE_STRING_FIELD(type, "CASE");
	WRITE_INT_FIELD(varno, stmt->t_varno);
	if (stmt->t_expr)
		dump_expr(str, stmt->t_expr);
	foreach(l, stmt->case_when_list)
	{
		PLpgSQL_case_when *cwt = (PLpgSQL_case_when *) lfirst(l);

		appendStringInfo(str, "WHEN ");
		dump_expr(str, cwt->expr);
		appendStringInfo(str, "THEN");
		dump_stmts(str, cwt->stmts);
	}
	if (stmt->have_else)
	{
		appendStringInfo(str, "ELSE");
		dump_stmts(str, stmt->else_stmts);
	}
}

static void
dump_loop(StringInfo str, PLpgSQL_stmt_loop *stmt)
{
	WRITE_STRING_FIELD(type, "LOOP");
	dump_stmts(str, stmt->body);
}

static void
dump_while(StringInfo str, PLpgSQL_stmt_while *stmt)
{
	WRITE_STRING_FIELD(type, "WHILE");
	dump_expr(str, stmt->cond);
	dump_stmts(str, stmt->body);
}

static void
dump_fori(StringInfo str, PLpgSQL_stmt_fori *stmt)
{
	appendStringInfo(str, "FORI %s %s", stmt->var->refname, (stmt->reverse) ? "REVERSE" : "NORMAL");

	appendStringInfo(str, "    lower = ");
	dump_expr(str, stmt->lower);
	appendStringInfo(str, "    upper = ");
	dump_expr(str, stmt->upper);
	if (stmt->step)
	{
		appendStringInfo(str, "    step = ");
		dump_expr(str, stmt->step);
	}

	dump_stmts(str, stmt->body);

	appendStringInfo(str, "    ENDFORI");
}

static void
dump_fors(StringInfo str, PLpgSQL_stmt_fors *stmt)
{
	WRITE_STRING_FIELD(type, "FORS");
	WRITE_STRING_FIELD(refname, (stmt->rec != NULL) ? stmt->rec->refname : stmt->row->refname);

	dump_expr(str, stmt->query);

	dump_stmts(str, stmt->body);
}

static void
dump_forc(StringInfo str, PLpgSQL_stmt_forc *stmt)
{
	appendStringInfo(str, "FORC %s ", stmt->rec->refname);
	appendStringInfo(str, "curvar=%d", stmt->curvar);

	if (stmt->argquery != NULL)
	{
		appendStringInfo(str, "  arguments = ");
		dump_expr(str, stmt->argquery);
	}

	dump_stmts(str, stmt->body);

	appendStringInfo(str, "    ENDFORC");
}

static void
dump_foreach_a(StringInfo str, PLpgSQL_stmt_foreach_a *stmt)
{
	appendStringInfo(str, "FOREACHA var %d ", stmt->varno);
	if (stmt->slice != 0)
		appendStringInfo(str, "SLICE %d ", stmt->slice);
	appendStringInfo(str, "IN ");
	dump_expr(str, stmt->expr);

	dump_stmts(str, stmt->body);

	appendStringInfo(str, "    ENDFOREACHA");
}

static void
dump_open(StringInfo str, PLpgSQL_stmt_open *stmt)
{
	appendStringInfo(str, "OPEN curvar=%d", stmt->curvar);

	if (stmt->argquery != NULL)
	{
		appendStringInfo(str, "  arguments = '");
		dump_expr(str, stmt->argquery);
	}
	if (stmt->query != NULL)
	{
		appendStringInfo(str, "  query = '");
		dump_expr(str, stmt->query);
	}
	if (stmt->dynquery != NULL)
	{
		appendStringInfo(str, "  execute = '");
		dump_expr(str, stmt->dynquery);

		if (stmt->params != NIL)
		{
			ListCell   *lc;
			int			i;

			appendStringInfo(str, "    USING");
			i = 1;
			foreach(lc, stmt->params)
			{
				appendStringInfo(str, "    parameter $%d: ", i++);
				dump_expr(str, (PLpgSQL_expr *) lfirst(lc));
			}
		}
	}
}

static void
dump_fetch(StringInfo str, PLpgSQL_stmt_fetch *stmt)
{
	if (!stmt->is_move)
	{
		appendStringInfo(str, "FETCH curvar=%d", stmt->curvar);
		dump_cursor_direction(str, stmt);

		if (stmt->rec != NULL)
		{
			appendStringInfo(str, "    target = %d %s", stmt->rec->dno, stmt->rec->refname);
		}
		if (stmt->row != NULL)
		{
			appendStringInfo(str, "    target = %d %s", stmt->row->dno, stmt->row->refname);
		}
	}
	else
	{
		appendStringInfo(str, "MOVE curvar=%d", stmt->curvar);
		dump_cursor_direction(str, stmt);
	}
}

static void
dump_cursor_direction(StringInfo str, PLpgSQL_stmt_fetch *stmt)
{
	switch (stmt->direction)
	{
		case FETCH_FORWARD:
			appendStringInfo(str, "    FORWARD ");
			break;
		case FETCH_BACKWARD:
			appendStringInfo(str, "    BACKWARD ");
			break;
		case FETCH_ABSOLUTE:
			appendStringInfo(str, "    ABSOLUTE ");
			break;
		case FETCH_RELATIVE:
			appendStringInfo(str, "    RELATIVE ");
			break;
		default:
			appendStringInfo(str, "??? unknown cursor direction %d", stmt->direction);
	}

	if (stmt->expr)
	{
		dump_expr(str, stmt->expr);
	}
	else
		appendStringInfo(str, "%ld", stmt->how_many);

}

static void
dump_close(StringInfo str, PLpgSQL_stmt_close *stmt)
{
	appendStringInfo(str, "CLOSE curvar=%d", stmt->curvar);
}

static void
dump_perform(StringInfo str, PLpgSQL_stmt_perform *stmt)
{
	appendStringInfo(str, "PERFORM expr = ");
	dump_expr(str, stmt->expr);
}

static void
dump_exit(StringInfo str, PLpgSQL_stmt_exit *stmt)
{
	appendStringInfo(str, "%s", stmt->is_exit ? "EXIT" : "CONTINUE");
	if (stmt->label != NULL)
		appendStringInfo(str, " label='%s'", stmt->label);
	if (stmt->cond != NULL)
	{
		appendStringInfo(str, " WHEN ");
		dump_expr(str, stmt->cond);
	}
}

static void
dump_return(StringInfo str, PLpgSQL_stmt_return *stmt)
{
	WRITE_STRING_FIELD(type, "RETURN");

	if (stmt->retvarno >= 0)
	  WRITE_UINT_FIELD(variable, stmt->retvarno);
	else if (stmt->expr != NULL)
		WRITE_STRING_FIELD(expr, stmt->expr->query);
	else
		WRITE_NULL_FIELD(expr);

	removeTrailingDelimiter(str);
}

static void
dump_return_next(StringInfo str, PLpgSQL_stmt_return_next *stmt)
{
	appendStringInfo(str, "RETURN NEXT ");
	if (stmt->retvarno >= 0)
		appendStringInfo(str, "variable %d", stmt->retvarno);
	else if (stmt->expr != NULL)
		dump_expr(str, stmt->expr);
	else
		appendStringInfo(str, "NULL");
}

static void
dump_return_query(StringInfo str, PLpgSQL_stmt_return_query *stmt)
{
	if (stmt->query)
	{
		appendStringInfo(str, "RETURN QUERY ");
		dump_expr(str, stmt->query);
	}
	else
	{
		appendStringInfo(str, "RETURN QUERY EXECUTE ");
		dump_expr(str, stmt->dynquery);
		if (stmt->params != NIL)
		{
			ListCell   *lc;
			int			i;

			appendStringInfo(str, "    USING");
			i = 1;
			foreach(lc, stmt->params)
			{
				appendStringInfo(str, "    parameter $%d: ", i++);
				dump_expr(str, (PLpgSQL_expr *) lfirst(lc));
			}
		}
	}
}

static void
dump_raise(StringInfo str, PLpgSQL_stmt_raise *stmt)
{
	ListCell   *lc;
	int			i = 0;

	appendStringInfo(str, "RAISE level=%d", stmt->elog_level);
	if (stmt->condname)
		appendStringInfo(str, " condname='%s'", stmt->condname);
	if (stmt->message)
		appendStringInfo(str, " message='%s'", stmt->message);
	foreach(lc, stmt->params)
	{
		appendStringInfo(str, "    parameter %d: ", i++);
		dump_expr(str, (PLpgSQL_expr *) lfirst(lc));
	}
	if (stmt->options)
	{
		appendStringInfo(str, "    USING");
		foreach(lc, stmt->options)
		{
			PLpgSQL_raise_option *opt = (PLpgSQL_raise_option *) lfirst(lc);

			switch (opt->opt_type)
			{
				case PLPGSQL_RAISEOPTION_ERRCODE:
					appendStringInfo(str, "    ERRCODE = ");
					break;
				case PLPGSQL_RAISEOPTION_MESSAGE:
					appendStringInfo(str, "    MESSAGE = ");
					break;
				case PLPGSQL_RAISEOPTION_DETAIL:
					appendStringInfo(str, "    DETAIL = ");
					break;
				case PLPGSQL_RAISEOPTION_HINT:
					appendStringInfo(str, "    HINT = ");
					break;
				case PLPGSQL_RAISEOPTION_COLUMN:
					appendStringInfo(str, "    COLUMN = ");
					break;
				case PLPGSQL_RAISEOPTION_CONSTRAINT:
					appendStringInfo(str, "    CONSTRAINT = ");
					break;
				case PLPGSQL_RAISEOPTION_DATATYPE:
					appendStringInfo(str, "    DATATYPE = ");
					break;
				case PLPGSQL_RAISEOPTION_TABLE:
					appendStringInfo(str, "    TABLE = ");
					break;
				case PLPGSQL_RAISEOPTION_SCHEMA:
					appendStringInfo(str, "    SCHEMA = ");
					break;
			}
			dump_expr(str, opt->expr);
		}
	}
}

static void
dump_execsql(StringInfo str, PLpgSQL_stmt_execsql *stmt)
{
	WRITE_STRING_FIELD(type, "EXECSQL");
	WRITE_STRING_FIELD(query, stmt->sqlstmt->query);

	if (stmt->rec != NULL)
	{
		appendStringInfo(str, "    INTO%s target = %d %s",
			   stmt->strict ? " STRICT" : "",
			   stmt->rec->dno, stmt->rec->refname);
	}
	if (stmt->row != NULL)
	{
		appendStringInfo(str, "    INTO%s target = %d %s",
			   stmt->strict ? " STRICT" : "",
			   stmt->row->dno, stmt->row->refname);
	}
	removeTrailingDelimiter(str);
}

static void
dump_dynexecute(StringInfo str, PLpgSQL_stmt_dynexecute *stmt)
{
	WRITE_STRING_FIELD(type, "EXECUTE");
	dump_expr(str, stmt->query);

	WRITE_BOOL_FIELD(strict, stmt->strict);
	if (stmt->rec != NULL)
	{
		WRITE_STRING_FIELD(target, "rec");
		WRITE_INT_FIELD(target_dno, stmt->rec->dno);
		WRITE_STRING_FIELD(target_refname, stmt->rec->refname);
	}
	if (stmt->row != NULL)
	{
		WRITE_STRING_FIELD(target, "row");
		WRITE_INT_FIELD(target_dno, stmt->row->dno);
		WRITE_STRING_FIELD(target_refname, stmt->row->refname);
	}
	if (stmt->params != NIL)
	{
		ListCell   *lc;
		int			i = 1;

		appendStringInfoString(str, "\"params\": ");
		appendStringInfoChar(str, '[');
		foreach(lc, stmt->params)
		{
			WRITE_INT_FIELD(paramno, i++);
			dump_expr(str, (PLpgSQL_expr *) lfirst(lc));
		}
		removeTrailingDelimiter(str);
		appendStringInfoString(str, "], ");
	}
}

static void
dump_dynfors(StringInfo str, PLpgSQL_stmt_dynfors *stmt)
{
	appendStringInfo(str, "FORS %s EXECUTE ",
		   (stmt->rec != NULL) ? stmt->rec->refname : stmt->row->refname);
	dump_expr(str, stmt->query);
	if (stmt->params != NIL)
	{
		ListCell   *lc;
		int			i;

		appendStringInfo(str, "    USING");
		i = 1;
		foreach(lc, stmt->params)
		{
			appendStringInfo(str, "    parameter $%d: ", i++);
			dump_expr(str, (PLpgSQL_expr *) lfirst(lc));
		}
	}
	dump_stmts(str, stmt->body);
	appendStringInfo(str, "    ENDFORS");
}

static void
dump_getdiag(StringInfo str, PLpgSQL_stmt_getdiag *stmt)
{
	ListCell   *lc;

	appendStringInfo(str, "GET %s DIAGNOSTICS ", stmt->is_stacked ? "STACKED" : "CURRENT");
	foreach(lc, stmt->diag_items)
	{
		PLpgSQL_diag_item *diag_item = (PLpgSQL_diag_item *) lfirst(lc);

		if (lc != list_head(stmt->diag_items))
			appendStringInfo(str, ", ");

		appendStringInfo(str, "{var %d} = %s", diag_item->target,
			   plpgsql_getdiag_kindname(diag_item->kind));
	}
}

static void
dump_expr(StringInfo str, PLpgSQL_expr *expr)
{
	WRITE_STRING_FIELD(expr, expr->query);
}

static void
dump_function(StringInfo str, PLpgSQL_function *func)
{
	int			i;
	PLpgSQL_datum *d;

  appendStringInfoChar(str, '{');
  WRITE_STRING_FIELD(signature, func->fn_signature);
	appendStringInfoString(str, "\"data_area\": ");
	appendStringInfoChar(str, '[');

	for (i = 0; i < func->ndatums; i++)
	{
	  appendStringInfoChar(str, '{');
		d = func->datums[i];

		WRITE_INT_FIELD(entry, i);
		switch (d->dtype)
		{
			case PLPGSQL_DTYPE_VAR:
				{
					PLpgSQL_var *var = (PLpgSQL_var *) d;

					WRITE_STRING_FIELD(type, "VAR");

					WRITE_STRING_FIELD(refname, var->refname);
					WRITE_STRING_FIELD(type, var->datatype->typname);
					WRITE_UINT_FIELD(typoid, var->datatype->typoid);
					WRITE_INT_FIELD(atttypmod, var->datatype->atttypmod);

					if (var->isconst)
						appendStringInfo(str, "CONSTANT");
					if (var->notnull)
						appendStringInfo(str, "NOT NULL");
					if (var->default_val != NULL)
					{
						appendStringInfo(str, "DEFAULT ");
						dump_expr(str, var->default_val);
					}
					if (var->cursor_explicit_expr != NULL)
					{
						if (var->cursor_explicit_argrow >= 0)
							appendStringInfo(str, "CURSOR argument row %d", var->cursor_explicit_argrow);

						appendStringInfo(str, "CURSOR IS ");
						dump_expr(str, var->cursor_explicit_expr);
					}
				}
				break;
			case PLPGSQL_DTYPE_ROW:
				{
					PLpgSQL_row *row = (PLpgSQL_row *) d;
					int			i;

					WRITE_STRING_FIELD(type, "ROW");
					WRITE_STRING_FIELD(refname, row->refname);
					appendStringInfoString(str, "\"data_area\": ");
					appendStringInfoChar(str, '[');

					for (i = 0; i < row->nfields; i++)
					{
						if (row->fieldnames[i]) {
							WRITE_STRING_FIELD(name, row->fieldnames[i]);
							WRITE_INT_FIELD(varno, row->varnos[i]);
						}
					}
					appendStringInfoString(str, "], ");
				}
				break;
			case PLPGSQL_DTYPE_REC:
				WRITE_STRING_FIELD(type, "REC");
				WRITE_STRING_FIELD(refname, ((PLpgSQL_rec *) d)->refname);
				break;
			case PLPGSQL_DTYPE_RECFIELD:
				WRITE_STRING_FIELD(type, "RECFIELD");
				WRITE_STRING_FIELD(fieldname, ((PLpgSQL_recfield *) d)->fieldname);
				WRITE_INT_FIELD(recparentno, ((PLpgSQL_recfield *) d)->recparentno);
				break;
			case PLPGSQL_DTYPE_ARRAYELEM:
				WRITE_STRING_FIELD(type, "ARRAYELEM");
				WRITE_INT_FIELD(arrayparentno, ((PLpgSQL_arrayelem *) d)->arrayparentno);
				dump_expr(str, ((PLpgSQL_arrayelem *) d)->subscript);
				break;
			default:
				WRITE_STRING_FIELD(type, "UNKNOWN");
				WRITE_INT_FIELD(dtype, d->dtype);
		}
		removeTrailingDelimiter(str);
		appendStringInfoString(str, "}, ");
	}

	removeTrailingDelimiter(str);

	appendStringInfoString(str, "], ");
	appendStringInfoString(str, "\"definition\": ");

  appendStringInfoChar(str, '{');
	WRITE_INT_FIELD(lineno, func->action->lineno);
	dump_block(str, func->action);
	appendStringInfoChar(str, '}');

  appendStringInfoChar(str, '}');
}

char *
plpgsqlToJSON(PLpgSQL_function *func)
{

	StringInfoData str;

	initStringInfo(&str);
  dump_function(&str, func);

  return str.data;
}
