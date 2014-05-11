#include "postgres.h"

#include <ctype.h>
#include <float.h>
#include <math.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>
#include "utils/memutils.h"
#include "parser/parser.h"
#include "nodes/print.h"

#include <ruby.h>

const char* progname = "pg_queryparser";

static VALUE pg_queryparser_raw_parse(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);
	
	MemoryContext ctx = NULL;
	List *tree;
	char *str;
	VALUE result;
	
	MemoryContextInit();

	ctx = AllocSetContextCreate(TopMemoryContext,
								"RootContext",
								ALLOCSET_DEFAULT_MINSIZE,
								ALLOCSET_DEFAULT_INITSIZE,
								ALLOCSET_DEFAULT_MAXSIZE);
	MemoryContextSwitchTo(ctx);

	str = StringValueCStr(input);
	tree = raw_parser((char*) str);
	
	if (tree == NULL) {
		MemoryContextSwitchTo(TopMemoryContext);
		MemoryContextDelete(ctx);
		rb_raise(rb_eArgError, "failed to parse query");
	}
	
	str = nodeToString(tree);
	
	result = rb_tainted_str_new_cstr(str);
	pfree(str);

	MemoryContextSwitchTo(TopMemoryContext);
	MemoryContextDelete(ctx);
	
	return result;
}

void Init_pg_queryparser(void)
{
	VALUE cPgQueryparser;

	cPgQueryparser = rb_const_get(rb_cObject, rb_intern("PgQueryparser"));

	rb_define_singleton_method(cPgQueryparser, "_raw_parse", pg_queryparser_raw_parse, 1);
}