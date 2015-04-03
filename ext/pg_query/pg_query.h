#ifndef PG_QUERY_H
#define PG_QUERY_H

#include "postgres.h"
#include "utils/memutils.h"

#include <ruby.h>

void Init_pg_query(void);
VALUE pg_query_normalize(VALUE self, VALUE input);
VALUE pg_query_raw_parse(VALUE self, VALUE input);

#endif
