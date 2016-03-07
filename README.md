# pg_query [ ![](https://img.shields.io/gem/v/pg_query.svg)](https://rubygems.org/gems/pg_query) [ ![](https://img.shields.io/gem/dt/pg_query.svg)](https://rubygems.org/gems/pg_query) [ ![](https://travis-ci.org/lfittl/pg_query.svg?branch=master)](https://travis-ci.org/lfittl/pg_query)

This Ruby extension uses the actual PostgreSQL server source to parse SQL queries and return the internal PostgreSQL parsetree.

In addition the extension allows you to normalize queries (replacing constant values with ?) and parse these normalized queries into a parsetree again.

When you build this extension, it fetches a copy of the PostgreSQL server source and builds parts of it, and then statically links it into this extension.

This is slightly crazy, but is the only reliable way of parsing all valid PostgreSQL queries.

You can find further examples and a longer rationale here: https://pganalyze.com/blog/parse-postgresql-queries-in-ruby.html

## Installation

```
gem install pg_query
```

Due to compiling parts of PostgreSQL, installation might take a while on slower systems. Expect up to 5 minutes.

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
 @tree=
  [{"SelectStmt"=>{"targetList"=>
               [{"ResTarget"=>
                 {"val"=>
                  {"ColumnRef"=>
                    {"fields"=>[{"A_Star"=>{}}],
                     "location"=>7}},
                  "location"=>7}}],
               "fromClause"=>
               [{"RangeVar"=>
                 {"relname"=>"users",
                  "inhOpt"=>2,
                  "relpersistence"=>"p",
                  "location"=>14}}],
               ...}}],
 @query="SELECT * FROM users",
 @warnings=[]>

# Modify the parse tree in some way
parsed_query.tree[0]['SelectStmt']['fromClause'][0]['RangeVar']['relname'] = 'other_users'

# Turn it into SQL again
parsed_query.deparse
=> "SELECT * FROM \"other_users\""
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
  [{"SelectStmt"=>
     {"targetList"=>
       [{"ResTarget"=>
          {"val"=>{"ParamRef"=>{"location"=>7}},
           "location"=>7}}],
      "fromClause"=>
       [{"RangeVar"=>
          {"relname"=>"x",
           "inhOpt"=>2,
           "relpersistence"=>"p",
           "location"=>14}}],
      "whereClause"=>
       {"A_Expr"=>
         {"kind"=>0,
          "name"=>[{"String"=>{"str"=>"="}}],
          "lexpr"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"y"}}], "location"=>22}},
          "rexpr"=>{"ParamRef"=>{"location"=>26}},
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

=> "8e1acac181c6d28f4a923392cf1c4eda49ee4cd2"

PgQuery.parse("SELECT 2; --- comment").fingerprint

=> "8e1acac181c6d28f4a923392cf1c4eda49ee4cd2"

# Faster fingerprint method that is implemented inside the native library
PgQuery.fingerprint("SELECT ?")

=> "8e1acac181c6d28f4a923392cf1c4eda49ee4cd2"
```

## Differences from Upstream PostgreSQL

This gem is based on [libpg_query](https://github.com/lfittl/libpg_query),
which uses the latest stable PostgreSQL version, but with a patch applied
to support parsing normalized queries containing `?` replacement characters.


## Original Author

- [Lukas Fittl](mailto:lukas@fittl.com)


## Special Thanks to

- [Jack Danger Canty](https://github.com/JackDanger), for significantly improving deparsing


## License

Copyright (c) 2015, pganalyze Team <team@pganalyze.com><br>
pg_query is licensed under the 3-clause BSD license, see LICENSE file for details.

Query normalization code:<br>
Copyright (c) 2008-2015, PostgreSQL Global Development Group
