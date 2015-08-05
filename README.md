# pg_query [ ![](https://img.shields.io/gem/v/pg_query.svg)](https://rubygems.org/gems/pg_query) [ ![](https://img.shields.io/gem/dt/pg_query.svg)](https://rubygems.org/gems/pg_query) [ ![Codeship Status for lfittl/dblint](https://img.shields.io/codeship/584524e0-ed17-0131-838b-4216c01ccc74.svg)](https://codeship.com/projects/26651)

This Ruby extension uses the actual PostgreSQL server source to parse SQL queries and return the internal PostgreSQL parsetree.

In addition the extension allows you to normalize queries (replacing constant values with ?) and parse these normalized queries into a parsetree again.

When you build this extension, it fetches a copy of the PostgreSQL server source and builds parts of it, and then statically links it into this extension.

This is slightly crazy, but is the only reliable way of parsing all valid PostgreSQL queries.

You can find further examples and a longer rationale here: https://pganalyze.com/blog/parse-postgresql-queries-in-ruby.html

## Installation

```
gem install pg_query
```

Due to compiling parts of PostgreSQL, installation will take a while. Expect between 2 and 10 minutes.

Note: On some Linux systems you'll have to install the ```flex``` package beforehand.

## Usage

### Parsing a query

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
      ...}}],
 @query="SELECT 1",
 @warnings=[]>
```

### Modifying a parsed query and turning it into SQL again

```ruby
parsed_query = PgQuery.parse("SELECT * FROM users")

=> #<PgQuery:0x007ff3e956c8b0
 @parsetree=
  [{"SELECT"=>{"distinctClause"=>nil,
               "intoClause"=>nil,
               "targetList"=>
               [{"RESTARGET"=>
                 {"name"=>nil,
                  "indirection"=>nil,
                  "val"=>
                  {"COLUMNREF"=>
                    {"fields"=>[{"A_STAR"=>{}}],
                     "location"=>7}},
                  "location"=>7}}],
               "fromClause"=>
               [{"RANGEVAR"=>
                 {"schemaname"=>nil,
                  "relname"=>"users",
                  "inhOpt"=>2,
                  "relpersistence"=>"p",
                  "alias"=>nil,
                  "location"=>14}}],
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
               "all"=>false,
               "larg"=>nil,
               "rarg"=>nil}}],
 @query="SELECT * FROM users",
 @warnings=[]>

# Modify the parse tree in some way
parsed_query.parsetree[0]['SELECT']['fromClause'][0]['RANGEVAR']['relname'] = 'other_users'

# Turn it into SQL again
parsed_query.deparse
=> "SELECT * FROM other_users"
```

Note: The deparsing feature is experimental and does not support outputting all SQL yet.

### Parsing a normalized query

```ruby
# Normalizing a query (like pg_stat_statements)
PgQuery.normalize("SELECT 1 FROM x WHERE y = 'foo'")

=> "SELECT ? FROM x WHERE y = ?"

# Parsing a normalized query
PgQuery.parse("SELECT ? FROM x WHERE y = ?")

=> #<PgQuery:0x007fb99455a438
 @parsetree=
  [{"SELECT"=>
     {"distinctClause"=>nil,
      "intoClause"=>nil,
      "targetList"=>
       [{"RESTARGET"=>
          {"name"=>nil,
           "indirection"=>nil,
           "val"=>{"PARAMREF"=>{"number"=>0, "location"=>7}},
           "location"=>7}}],
      "fromClause"=>
       [{"RANGEVAR"=>
          {"schemaname"=>nil,
           "relname"=>"x",
           "inhOpt"=>2,
           "relpersistence"=>"p",
           "alias"=>nil,
           "location"=>14}}],
      "whereClause"=>
       {"AEXPR"=>
         {"name"=>["="],
          "lexpr"=>{"COLUMNREF"=>{"fields"=>["y"], "location"=>22}},
          "rexpr"=>{"PARAMREF"=>{"number"=>0, "location"=>26}},
          "location"=>24}},
      ...}}],
 @query="SELECT ? FROM x WHERE y = ?",
 @warnings=[]>
```

### Extracting tables from a query

```ruby
PgQuery.parse("SELECT ? FROM x JOIN y USING (id) WHERE z = ?").tables

=> ["x", "y"]
```

### Extracting columns from a query

```ruby
PgQuery.parse("SELECT ? FROM x WHERE x.y = ? AND z = ?").filter_columns

=> [["x", "y"], [nil, "z"]]
```

### Fingerprinting a query

```ruby
PgQuery.parse("SELECT 1").fingerprint

=> "db76551255b7861b99bd384cf8096a3dd5162ab3"

PgQuery.parse("SELECT 2; --- comment").fingerprint

=> "db76551255b7861b99bd384cf8096a3dd5162ab3"
```

## Differences from Upstream PostgreSQL

**This gem uses a [patched version of the latest PostgreSQL stable](https://github.com/pganalyze/postgres/compare/REL9_4_STABLE...pg_query).**

Changes:
* **scan.l/gram.y:** Modified to support parsing normalized queries
 * Known regression: Removed support for custom operators containing "?" (doesn't affect hstore/JSON/geometric operators)
* **outfuncs_json.c:** Auto-generated outfuncs that outputs a parsetree as JSON (called through nodeToJSONString)

Unit tests for these patches are inside this library - the tests will break if run against upstream.


## Authors

- [Lukas Fittl](mailto:lukas@fittl.com)


## License

Copyright (c) 2015, pganalyze Team <team@pganalyze.com><br>
pg_query is licensed under the 3-clause BSD license, see LICENSE file for details.

Query normalization code:<br>
Copyright (c) 2008-2015, PostgreSQL Global Development Group
