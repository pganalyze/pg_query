#include "pg_query.h"
#include "postgres_deparse.h"
#include "xxhash/xxhash.h"
#include <ruby.h>

void raise_ruby_parse_error(PgQueryProtobufParseResult result);
void raise_ruby_normalize_error(PgQueryNormalizeResult result);
void raise_ruby_fingerprint_error(PgQueryFingerprintResult result);
void raise_ruby_scan_error(PgQueryScanResult result);
void raise_ruby_split_error(PgQuerySplitResult result);

VALUE pg_query_ruby_parse_protobuf(VALUE self, VALUE input);
VALUE pg_query_ruby_deparse_protobuf(VALUE self, VALUE input);
VALUE pg_query_ruby_deparse_protobuf_opts(VALUE self, VALUE input, VALUE pretty_print, VALUE comments, VALUE indent_size, VALUE max_line_length, VALUE trailing_newline, VALUE commas_start_of_line);
VALUE pg_query_ruby_deparse_comments_for_query(VALUE self, VALUE input);
VALUE pg_query_ruby_normalize(VALUE self, VALUE input);
VALUE pg_query_ruby_fingerprint(VALUE self, VALUE input);
VALUE pg_query_ruby_scan(VALUE self, VALUE input);
VALUE pg_query_ruby_split_with_parser(VALUE self, VALUE input);
VALUE pg_query_ruby_hash_xxh3_64(VALUE self, VALUE input, VALUE seed);

__attribute__((visibility ("default"))) void Init_pg_query(void)
{
	VALUE cPgQuery;

	cPgQuery = rb_const_get(rb_cObject, rb_intern("PgQuery"));

	rb_define_singleton_method(cPgQuery, "parse_protobuf", pg_query_ruby_parse_protobuf, 1);
	rb_define_singleton_method(cPgQuery, "deparse_protobuf", pg_query_ruby_deparse_protobuf, 1);
	rb_define_singleton_method(cPgQuery, "deparse_protobuf_opts", pg_query_ruby_deparse_protobuf_opts, 7);
	rb_define_singleton_method(cPgQuery, "deparse_comments_for_query", pg_query_ruby_deparse_comments_for_query, 1);
	rb_define_singleton_method(cPgQuery, "normalize", pg_query_ruby_normalize, 1);
	rb_define_singleton_method(cPgQuery, "fingerprint", pg_query_ruby_fingerprint, 1);
	rb_define_singleton_method(cPgQuery, "_raw_scan", pg_query_ruby_scan, 1);
	rb_define_singleton_method(cPgQuery, "_raw_split_with_parser", pg_query_ruby_split_with_parser, 1);
	rb_define_singleton_method(cPgQuery, "hash_xxh3_64", pg_query_ruby_hash_xxh3_64, 2);
	rb_define_const(cPgQuery, "PG_VERSION", rb_str_new2(PG_VERSION));
	rb_define_const(cPgQuery, "PG_MAJORVERSION", rb_str_new2(PG_MAJORVERSION));
	rb_define_const(cPgQuery, "PG_VERSION_NUM", INT2NUM(PG_VERSION_NUM));
}

void raise_ruby_parse_error(PgQueryProtobufParseResult result)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_protobuf_parse_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cParseError));
}

void raise_ruby_deparse_error(PgQueryDeparseResult result)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_deparse_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cParseError));
}

void raise_ruby_deparse_comments_error(PgQueryDeparseCommentsResult result)
{
	VALUE cPgQuery, cParseError;
	VALUE args[4];

	cPgQuery    = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cParseError = rb_const_get_at(cPgQuery, rb_intern("ParseError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_deparse_comments_result(result);

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

void raise_ruby_split_error(PgQuerySplitResult result)
{
	VALUE cPgQuery, cSplitError;
	VALUE args[4];

	cPgQuery   = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cSplitError = rb_const_get_at(cPgQuery, rb_intern("SplitError"));

	args[0] = rb_str_new2(result.error->message);
	args[1] = rb_str_new2(result.error->filename);
	args[2] = INT2NUM(result.error->lineno);
	args[3] = INT2NUM(result.error->cursorpos);

	pg_query_free_split_result(result);

	rb_exc_raise(rb_class_new_instance(4, args, cSplitError));
}

VALUE pg_query_ruby_parse_protobuf(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryProtobufParseResult result = pg_query_parse_protobuf(StringValueCStr(input));

	if (result.error) raise_ruby_parse_error(result);

	output = rb_ary_new();

	rb_ary_push(output, rb_str_new(result.parse_tree.data, result.parse_tree.len));
	rb_ary_push(output, rb_str_new2(result.stderr_buffer));

	pg_query_free_protobuf_parse_result(result);

	return output;
}

VALUE pg_query_ruby_deparse_protobuf(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	PgQueryProtobuf pbuf = {0};
	PgQueryDeparseResult result = {0};

	pbuf.data = StringValuePtr(input);
	pbuf.len = RSTRING_LEN(input);
	result = pg_query_deparse_protobuf(pbuf);

	if (result.error) raise_ruby_deparse_error(result);

	output = rb_str_new2(result.query);

	pg_query_free_deparse_result(result);

	return output;
}

VALUE pg_query_ruby_deparse_protobuf_opts(VALUE self, VALUE input, VALUE pretty_print, VALUE comments, VALUE indent_size, VALUE max_line_length, VALUE trailing_newline, VALUE commas_start_of_line)
{
	Check_Type(input, T_STRING);
	Check_Type(comments, T_ARRAY);
	Check_Type(indent_size, T_FIXNUM);
	Check_Type(max_line_length, T_FIXNUM);

	VALUE output;
	PgQueryProtobuf pbuf = {0};
	PgQueryDeparseResult result = {0};
	PostgresDeparseOpts deparse_opts = {0};
	deparse_opts.pretty_print = RTEST(pretty_print);
	deparse_opts.indent_size = NUM2INT(indent_size);
	deparse_opts.max_line_length = NUM2INT(max_line_length);
	deparse_opts.trailing_newline = RTEST(trailing_newline);
	deparse_opts.commas_start_of_line = RTEST(commas_start_of_line);
	deparse_opts.comments = malloc(RARRAY_LEN(comments) * sizeof(PostgresDeparseComment *));
	deparse_opts.comment_count = RARRAY_LEN(comments);
	VALUE *comments_arr = RARRAY_PTR(comments);

	for (int i = 0; i < RARRAY_LEN(comments); i++)
	{
		PostgresDeparseComment* comment  = malloc(sizeof(PostgresDeparseComment));
		VALUE str_ref                    = rb_ivar_get(comments_arr[i], rb_intern("@str"));
		comment->match_location          = NUM2INT(rb_ivar_get(comments_arr[i], rb_intern("@match_location")));
		comment->newlines_before_comment = NUM2INT(rb_ivar_get(comments_arr[i], rb_intern("@newlines_before_comment")));
		comment->newlines_after_comment  = NUM2INT(rb_ivar_get(comments_arr[i], rb_intern("@newlines_after_comment")));
		comment->str                     = StringValueCStr(str_ref);

		deparse_opts.comments[i] = comment;
	}

	pbuf.data = StringValuePtr(input);
	pbuf.len = RSTRING_LEN(input);
	result = pg_query_deparse_protobuf_opts(pbuf, deparse_opts);

	if (result.error) raise_ruby_deparse_error(result);

	output = rb_str_new2(result.query);

	pg_query_free_deparse_result(result);
	for (int i = 0; i < deparse_opts.comment_count; i++)
		free(deparse_opts.comments[i]);
	free(deparse_opts.comments);

	return output;
}

VALUE pg_query_ruby_deparse_comments_for_query(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE cPgQuery, cDeparseComment;

	cPgQuery        = rb_const_get(rb_cObject, rb_intern("PgQuery"));
	cDeparseComment = rb_const_get_at(cPgQuery, rb_intern("DeparseComment"));

	VALUE output = rb_ary_new();
	PgQueryDeparseCommentsResult result = pg_query_deparse_comments_for_query(StringValueCStr(input));
	if (result.error) raise_ruby_deparse_comments_error(result);

	for (int i = 0; i < result.comment_count; i++)
	{
		PostgresDeparseComment* comment = result.comments[i];
		VALUE c = rb_class_new_instance(0, NULL, cDeparseComment);
		rb_ivar_set(c, rb_intern("@str"), rb_str_new2(comment->str));
		rb_ivar_set(c, rb_intern("@match_location"), INT2NUM(comment->match_location));
		rb_ivar_set(c, rb_intern("@newlines_before_comment"), INT2NUM(comment->newlines_before_comment));
		rb_ivar_set(c, rb_intern("@newlines_after_comment"), INT2NUM(comment->newlines_after_comment));
		rb_ary_push(output, c);
	}

	pg_query_free_deparse_comments_result(result);

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

	if (result.fingerprint_str) {
		output = rb_str_new2(result.fingerprint_str);
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

	rb_ary_push(output, rb_str_new(result.pbuf.data, result.pbuf.len));
	rb_ary_push(output, rb_str_new2(result.stderr_buffer));

	pg_query_free_scan_result(result);

	return output;
}

VALUE pg_query_ruby_split_with_parser(VALUE self, VALUE input)
{
	Check_Type(input, T_STRING);

	VALUE output;
	VALUE stmts;
	PgQuerySplitResult result = pg_query_split_with_parser(StringValueCStr(input));

	if (result.error) raise_ruby_split_error(result);

	output = rb_ary_new();
	stmts = rb_ary_new();

	for (int i = 0; i < result.n_stmts; i++)
	{
		VALUE stmt = rb_ary_new();
		rb_ary_push(stmt, INT2NUM(result.stmts[i]->stmt_location));
		rb_ary_push(stmt, INT2NUM(result.stmts[i]->stmt_len));
		rb_ary_push(stmts, stmt);
	}

	rb_ary_push(output, stmts);
	rb_ary_push(output, rb_str_new2(result.stderr_buffer));

	pg_query_free_split_result(result);

	return output;
}

VALUE pg_query_ruby_hash_xxh3_64(VALUE self, VALUE input, VALUE seed)
{
	Check_Type(input, T_STRING);
	Check_Type(seed, T_FIXNUM);

#ifdef HAVE_LONG_LONG
	return ULL2NUM(XXH3_64bits_withSeed(StringValuePtr(input), RSTRING_LEN(input), NUM2ULONG(seed)));
#else
	return ULONG2NUM(XXH3_64bits_withSeed(StringValuePtr(input), RSTRING_LEN(input), NUM2ULONG(seed)));
#endif
	
}
