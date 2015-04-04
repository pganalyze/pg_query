/* Polyfills to avoid building unnecessary objects from the PostgreSQL source */

#include "postgres.h"
#include "plpgsql.h"

/* src/backend/postmaster/postmaster.c */
bool ClientAuthInProgress = false;
bool redirection_done = false;

/* src/backend/postmaster/syslogger.c */
bool am_syslogger = false;

/* src/backend/tcop/postgres.c */
#include "tcop/dest.h"
const char *debug_query_string;
CommandDest whereToSendOutput = DestDebug;

/* src/backend/utils/misc/guc.c */
char *application_name;
int client_min_messages = NOTICE;
int log_min_error_statement = ERROR;
int log_min_messages = WARNING;
int trace_recovery_messages = LOG;
bool check_function_bodies = true;

/* src/backend/storage/lmgr/proc.c */
#include "storage/proc.h"
PGPROC *MyProc = NULL;

/* src/backend/storage/ipc/ipc.c */
bool proc_exit_inprogress = false;

/* src/backend/tcop/postgres.c */
#include "miscadmin.h"
void check_stack_depth(void) { /* Do nothing */ }

/* src/backends/commands/define.c */
#include "commands/defrem.h"
#include "nodes/makefuncs.h"
DefElem * defWithOids(bool value)
{
  return makeDefElem("oids", (Node *) makeInteger(value));
}

/* src/pl/plpgsql/src/ph_handler.c */
int plpgsql_variable_conflict = PLPGSQL_RESOLVE_ERROR;
bool plpgsql_print_strict_params = false;
int plpgsql_extra_warnings;
int plpgsql_extra_errors;

/* src/backend/catalog/pg_proc.c */
#include "catalog/pg_proc_fn.h"
bool function_parse_error_transpose(const char *prosrc)
{
	return false;
}

/* src/backend/parser/parse_type.c */
#include "parser/parse_type.h"
void parseTypeString(const char *str, Oid *typeid_p, int32 *typmod_p, bool missing_ok)
{
  *typeid_p = InvalidOid;
  return;
}
