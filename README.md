pg_query
========

This Ruby extension uses the actual PostgreSQL server source to parse SQL queries and return the internal PostgreSQL parsetree.

When you build this extension, it fetches a copy of the PostgreSQL server source and builds it, and then statically links it into this extension.

This is slightly crazy, but is the only reliable way of parsing all valid PostgreSQL queries.

**Note:** This gem uses a patched version of the latest PostgreSQL stable, [with improvements to outfuncs.c](https://github.com/pganalyze/postgres/compare/REL9_3_STABLE...more-outfuncs).

Installation
------------

```
gem install pg_query
```

Due to compiling PostgreSQL, installation will take a while. Expect up to 10 minutes on a fast machine.

Usage
-----

```ruby
PgQuery.parse("SELECT 1")

=> #<PgQuery:0x007fe92b27ea18
 @parsetree=
  [{"SELECT"=>
     {"distinctClause"=>nil,
      "intoClause"=>nil,
      "targetList"=>
       [{"RESTARGET"=>
          {"name"=>nil,
           "indirection"=>nil,
           "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}},
           "location"=>7}}],
      "fromClause"=>nil,
      "whereClause"=>nil,
      "groupClause"=>nil,
      "havingClause"=>nil,
      "windowClause"=>nil,
      "valuesLists"=>nil,
      "sortClause"=>nil,
      "limitOffset"=>nil,
      "limitCount"=>nil,
      "lockingClause"=>nil,
      "withClause"=>nil,
      "op"=>0,
      "all"=>"false",
      "larg"=>nil,
      "rarg"=>nil}}],
 @query="SELECT 1",
 @warnings=[]>
```

Authors
-------

- [Lukas Fittl](mailto:lukas@fittl.com)

License
-------

Copyright (c) 2014 pganalyze

pg_query is licensed under the PostgreSQL license, see LICENSE file for details.
