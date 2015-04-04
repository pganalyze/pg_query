#include "pg_query.h"

const char* progname = "pg_query";

void Init_pg_query(void)
{
	VALUE cPgQuery;

	MemoryContextInit();

	cPgQuery = rb_const_get(rb_cObject, rb_intern("PgQuery"));

	rb_define_singleton_method(cPgQuery, "_raw_parse", pg_query_raw_parse, 1);
	rb_define_singleton_method(cPgQuery, "_raw_parse_plpgsql", pg_query_raw_parse_plpgsql, 1);
	rb_define_singleton_method(cPgQuery, "normalize", pg_query_normalize, 1);
}
