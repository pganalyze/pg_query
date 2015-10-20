#include "pg_query_ruby.h"

void raise_ruby_error(PgQueryError* error);
VALUE pg_query_ruby_parse(VALUE self, VALUE input);
VALUE pg_query_ruby_normalize(VALUE self, VALUE input);

void Init_pg_query(void)
{
	VALUE cPgQuery;

	pg_query_init();

	cPgQuery = rb_const_get(rb_cObject, rb_intern("PgQuery"));

	rb_define_singleton_method(cPgQuery, "_raw_parse", pg_query_ruby_parse, 1);
	rb_define_singleton_method(cPgQuery, "normalize", pg_query_ruby_normalize, 1);
}

void raise_ruby_error(PgQueryError* error)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(error->message);
	args[1] = rb_str_new2(error->filename);
	args[2] = INT2NUM(error->lineno);
	args[3] = INT2NUM(error->cursorpos);

	free(error->message);
	free(error->filename);
	free(error);

	rb_exc_raise(rb_class_new_instance(4, args, cParseError));
}

VALUE pg_query_ruby_parse(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryParseResult result = pg_query_parse(StringValueCStr(input));

	if (result.error) raise_ruby_error(result.error);

	output = rb_ary_new();

	rb_ary_push(output, rb_str_new2(result.parse_tree));
	rb_ary_push(output, rb_str_new2(result.stderr_buffer));

	free(result.parse_tree);
	free(result.stderr_buffer);

	return output;
}

VALUE pg_query_ruby_normalize(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryNormalizeResult result = pg_query_normalize(StringValueCStr(input));

	if (result.error) raise_ruby_error(result.error);

	output = rb_str_new2(result.normalized_query);

	free(result.normalized_query);

	return output;
}
