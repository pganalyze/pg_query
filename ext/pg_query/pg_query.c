#include "postgres.h"
#include "utils/memutils.h"
#include "parser/parser.h"
#include "nodes/print.h"

#include <unistd.h>
#include <fcntl.h>

#include <ruby.h>

const char* progname = "pg_query";

static void raise_parse_error(ErrorData* error)
{
	VALUE cPgQuery, cParseError;
	VALUE exc, args[2];
	
	cPgQuery = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));
	
	args[0] = rb_tainted_str_new_cstr(error->message);
	args[1] = INT2NUM(error->cursorpos);
	
	exc = rb_class_new_instance(2, args, cParseError);
	
	rb_exc_raise(exc);
}

#define STDERR_BUFFER_LEN 4096

static VALUE pg_query_raw_parse(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);
	
	MemoryContext ctx = NULL;
	VALUE result;
	ErrorData* error = NULL;
	char stderr_buffer[STDERR_BUFFER_LEN + 1] = {0};
	int stderr_global;
	int stderr_pipe[2];

	ctx = AllocSetContextCreate(TopMemoryContext,
								"RootContext",
								ALLOCSET_DEFAULT_MINSIZE,
								ALLOCSET_DEFAULT_INITSIZE,
								ALLOCSET_DEFAULT_MAXSIZE);
	MemoryContextSwitchTo(ctx);
	
	// Setup pipe for stderr redirection
	if (pipe(stderr_pipe) != 0)
		rb_raise(rb_eIOError, "Failed to open pipe, too many open file descriptors");

	fcntl(stderr_pipe[0], F_SETFL, fcntl(stderr_pipe[0], F_GETFL) | O_NONBLOCK);
	
	// Redirect stderr to the pipe
	stderr_global = dup(STDERR_FILENO);
	dup2(stderr_pipe[1], STDERR_FILENO);
	close(stderr_pipe[1]);
	
	// Parse it!
	PG_TRY();
	{
		List *tree;
		char *str;
		
		str = StringValueCStr(input);
		tree = raw_parser(str);
		
		str = nodeToString(tree);
	
		// Save stderr for result
		read(stderr_pipe[0], stderr_buffer, STDERR_BUFFER_LEN);
	
		result = rb_ary_new();
		rb_ary_push(result, rb_tainted_str_new_cstr(str));
		rb_ary_push(result, rb_str_new2(stderr_buffer));
	
		pfree(str);
	}
	PG_CATCH();
	{
		error = CopyErrorData();
		FlushErrorState();
	}
	PG_END_TRY();
	
	// Restore stderr, close pipe & return to previous PostgreSQL memory context
	dup2(stderr_global, STDERR_FILENO);
	close(stderr_pipe[0]);
	MemoryContextSwitchTo(TopMemoryContext);
	MemoryContextDelete(ctx);
	
	// If we got an error, throw a ParseError exception
	if (error) raise_parse_error(error);
	
	return result;
}

void Init_pg_query(void)
{
	VALUE cPgQuery;
	
	MemoryContextInit();

	cPgQuery = rb_const_get(rb_cObject, rb_intern("PgQuery"));

	rb_define_singleton_method(cPgQuery, "_raw_parse", pg_query_raw_parse, 1);
}