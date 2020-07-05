#include "pg_query_ruby.h"

void raise_ruby_parse_error(PgQueryParseResult result);
void raise_ruby_normalize_error(PgQueryNormalizeResult result);
void raise_ruby_fingerprint_error(PgQueryFingerprintResult result);
void raise_ruby_scan_error(PgQueryScanResult result);

VALUE pg_query_ruby_parse(VALUE self, VALUE input);
VALUE pg_query_ruby_normalize(VALUE self, VALUE input);
VALUE pg_query_ruby_fingerprint(VALUE self, VALUE input);
VALUE pg_query_ruby_scan(VALUE self, VALUE input);

void Init_pg_query(void)
{
	VALUE cPgQuery;

	cPgQuery = rb_const_get(rb_cObject, rb_intern("PgQuery"));

	rb_define_singleton_method(cPgQuery, "_raw_parse", pg_query_ruby_parse, 1);
	rb_define_singleton_method(cPgQuery, "normalize", pg_query_ruby_normalize, 1);
	rb_define_singleton_method(cPgQuery, "fingerprint", pg_query_ruby_fingerprint, 1);
	rb_define_singleton_method(cPgQuery, "_raw_scan", pg_query_ruby_scan, 1);
}

void raise_ruby_parse_error(PgQueryParseResult result)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_parse_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cParseError));
}

void raise_ruby_normalize_error(PgQueryNormalizeResult result)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_normalize_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cParseError));
}

void raise_ruby_fingerprint_error(PgQueryFingerprintResult result)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_fingerprint_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cParseError));
}

void raise_ruby_scan_error(PgQueryScanResult result)
{
	VALUE cPgQuery, cScanError;
	VALUE args[4];

	cPgQuery   = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cScanError = rb_const_get_at(cPgQuery, rb_intern("ScanError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_scan_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cScanError));
}

VALUE pg_query_ruby_parse(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryParseResult result = pg_query_parse(StringValueCStr(input));

	if (result.error) raise_ruby_parse_error(result);

	output = rb_ary_new();

	rb_ary_push(output, rb_str_new2(result.parse_tree));
	rb_ary_push(output, rb_str_new2(result.stderr_buffer));

	pg_query_free_parse_result(result);

	return output;
}

VALUE pg_query_ruby_normalize(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryNormalizeResult result = pg_query_normalize(StringValueCStr(input));

	if (result.error) raise_ruby_normalize_error(result);

	output = rb_str_new2(result.normalized_query);

	pg_query_free_normalize_result(result);

	return output;
}

VALUE pg_query_ruby_fingerprint(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryFingerprintResult result = pg_query_fingerprint(StringValueCStr(input));

	if (result.error) raise_ruby_fingerprint_error(result);

	if (result.hexdigest) {
		output = rb_str_new2(result.hexdigest);
	} else {
		output = Qnil;
	}

	pg_query_free_fingerprint_result(result);

	return output;
}

VALUE pg_query_ruby_scan(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryScanResult result = pg_query_scan(StringValueCStr(input));

	if (result.error) raise_ruby_scan_error(result);

	output = rb_ary_new();

	rb_ary_push(output, rb_str_new(result.pbuf, result.pbuf_len));
	rb_ary_push(output, rb_str_new2(result.stderr_buffer));

	pg_query_free_scan_result(result);

	return output;
}