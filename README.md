This Ruby extension uses the actual PostgreSQL server source to parse SQL queries and return the internal PostgreSQL parsetree.

When you build this extension, it fetches a copy of the PostgreSQL server source and builds it, and then statically links it into this extension.

This is slightly crazy, but is the only reliable way of parsing all valid PostgreSQL queries.

#### Installation

```
gem install pg_queryparser
```

**Note:** Due to building a copy of PostgreSQL, installation will take a while.

#### Usage

```
PgQueryparser.parse("SELECT 1")
# => {"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}}, "location"=>7}}], "fromClause"=>nil, "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>"false", "larg"=>nil, "rarg"=>nil}}
```

#### PostgreSQL source repository

This gem uses a patched version of PostgreSQL, [with improvements to outfuncs.c](https://github.com/pganalyze/postgres/compare/REL9_3_STABLE...more-outfuncs).