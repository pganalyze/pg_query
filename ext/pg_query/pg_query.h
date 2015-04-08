#ifndef PG_QUERY_H
#define PG_QUERY_H

#include "postgres.h"
#include "utils/memutils.h"

#include <ruby.h>

#define STDERR_BUFFER_LEN 4096
//#define DEBUG

VALUE new_parse_error(ErrorData* error);

void Init_pg_query(void);
VALUE pg_query_normalize(VALUE self, VALUE input);
VALUE pg_query_raw_parse(VALUE self, VALUE input);

#endif
