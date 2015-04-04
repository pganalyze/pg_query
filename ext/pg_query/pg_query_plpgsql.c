#include "pg_query.h"
#include "pg_plpgsql_to_json.h"

VALUE pg_query_raw_parse_plpgsql(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	MemoryContext ctx = NULL;
	VALUE result = Qnil;
	VALUE error = Qnil;
	char stderr_buffer[STDERR_BUFFER_LEN + 1] = {0};
#ifndef DEBUG
	int stderr_global;
	int stderr_pipe[2];
#endif

	ctx = AllocSetContextCreate(TopMemoryContext,
								"pg_query_raw_parse_plpgsql",
								ALLOCSET_DEFAULT_MINSIZE,
								ALLOCSET_DEFAULT_INITSIZE,
								ALLOCSET_DEFAULT_MAXSIZE);
	MemoryContextSwitchTo(ctx);

#ifndef DEBUG
	// Setup pipe for stderr redirection
	if (pipe(stderr_pipe) != 0)
		rb_raise(rb_eIOError, "Failed to open pipe, too many open file descriptors");

	fcntl(stderr_pipe[0], F_SETFL, fcntl(stderr_pipe[0], F_GETFL) | O_NONBLOCK);

	// Redirect stderr to the pipe
	stderr_global = dup(STDERR_FILENO);
	dup2(stderr_pipe[1], STDERR_FILENO);
	close(stderr_pipe[1]);
#endif

	// Parse it!
	PG_TRY();
	{
		PLpgSQL_function *func;
		char *str;

		str = StringValueCStr(input);

		func = plpgsql_compile_inline(str);

		str = plpgsqlToJSON(func);

#ifndef DEBUG
		// Save stderr for result
		read(stderr_pipe[0], stderr_buffer, STDERR_BUFFER_LEN);
#endif

		result = rb_ary_new();
		rb_ary_push(result, rb_str_new2(str));
		rb_ary_push(result, rb_str_new2(stderr_buffer));

		plpgsql_free_function_memory(func);
		pfree(str);
	}
	PG_CATCH();
	{
		ErrorData* error_data = CopyErrorData();
		error = new_parse_error(error_data);
		FlushErrorState();
	}
	PG_END_TRY();

#ifndef DEBUG
	// Restore stderr, close pipe
	dup2(stderr_global, STDERR_FILENO);
	close(stderr_pipe[0]);
	close(stderr_global);
#endif

	// Return to previous PostgreSQL memory context
	MemoryContextSwitchTo(TopMemoryContext);
	MemoryContextDelete(ctx);

	// If we got an error, throw it
	if (!NIL_P(error)) rb_exc_raise(error);

	return result;
}
