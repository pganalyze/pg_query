# Changelog

## 1.2.0     2019-11-10

* Reduce escaped keywords to Postgres-specific keywords, and ignore unreserved keywords
  * This matches the behaviour of Postgres' quote_identifier function, and avoids problems
    when doing text comparisons with output involving that function
  * Note that this will lead to different output than in earlier pg_query versions,
    in some cases

## 1.1.1     2019-11-10

* Deparsing improvements by [@emin100](https://github.com/emin100)
  * Deparse ILIKE, COLLATE and DISCARD (#133)
  * CREATE CAST (#136)
  * CREATE SCHEMA (#136)
  * UNION, UNION ALL and EXCEPT in SELECT queries (#136)
  * CREATE DOMAIN (#145)
  * Subquery indirection (#157)
  * Fix Type Cast Parentheses Problem (#152)
  * SELECT INTO (#151)
  * SET DEFAULT in INSERT INTO (#154)
  * REVOKE (#155)
  * PREPARE and EXECUTE (#148)
  * INSERT INTO ... RETURNING (#153)
  * Fix Alter .. RENAME SQL (#146)
* Deparsing improvements by [@herwinw](https://github.com/herwinw)
  * Fix subquery in COPY in deparse (#112)
  * Function call indirection (#116)
  * Function without parameters (#117)
  * CREATE AGGREGATE
  * CREATE OPERATOR
  * CREATE TYPE
  * GRANT statements
  * DROP SCHEMA
* Deparsing improvements by [@akiellor](https://github.com/akiellor)
  * Named window functions (#150)
* Deparsing improvements by [@himanshu](https://github.com/himanshu)
  * Arguments in custom types (#143)
  * Use "double precision" instead of "double" type name (#139)
* Use explicit -z flag to support OpenBSD tar (#134) [@sirn](https://github.com/sirn)
* Add Ruby 2.6 to Travis tests
* Escape identifiers in more cases, if necessary


## 1.1.0     2018-10-04

* Deparsing improvements by [@herwinw](https://github.com/herwinw)
  * Add NULLS FIRST/LAST to ORDER BY [#95](https://github.com/lfittl/pg_query/pull/95)
  * VACUUM [#97](https://github.com/lfittl/pg_query/pull/97)
  * UPDATE with multiple columns [#99](https://github.com/lfittl/pg_query/pull/99)
  * DISTINCT ON [#101](https://github.com/lfittl/pg_query/pull/101)
  * CREATE TABLE AS [#102](https://github.com/lfittl/pg_query/pull/102)
  * SQL value functions [#103](https://github.com/lfittl/pg_query/pull/103)
  * LOCK [#105](https://github.com/lfittl/pg_query/pull/105)
  * EXPLAIN [#107](https://github.com/lfittl/pg_query/pull/107)
  * COPY [#108](https://github.com/lfittl/pg_query/pull/108)
  * DO [#109](https://github.com/lfittl/pg_query/pull/109)
* Ignore pg_query.so in git checkout [#110](https://github.com/lfittl/pg_query/pull/110) [@herwinw](https://github.com/herwinw)
* Prefer __dir__ over File.dirname(__FILE__) [#110](https://github.com/lfittl/pg_query/pull/104) [@herwinw](https://github.com/herwinw)


## 1.0.2     2018-04-11

* Deparsing improvements
  * SELECT DISTINCT clause [#77](https://github.com/lfittl/pg_query/pull/77) [@Papierkorb](https://github.com/Papierkorb)
  * "CASE expr WHEN ... END" clause [#78](https://github.com/lfittl/pg_query/pull/78) [@Papierkorb](https://github.com/Papierkorb)
  * LEFT/RIGHT/FULL/NATURAL JOIN [#79](https://github.com/lfittl/pg_query/pull/79) [@Papierkorb](https://github.com/Papierkorb)
  * SELECT that includes schema name [#80](https://github.com/lfittl/pg_query/pull/80) [@jcsjcs](https://github.com/jcsjcs)


## 1.0.1     2018-02-02

* Parse CTEs and nested selects in INSERT/UPDATE [#76](https://github.com/lfittl/pg_query/pull/76) [@jcoleman](https://github.com/jcoleman)
* Drop explicit json dependency [#74](https://github.com/lfittl/pg_query/pull/74) [@yuki24](https://github.com/yuki24)


## 1.0.0     2017-10-31

* IMPORTANT: Major version bump to indicate backwards incompatible parse tree change!
* Update to Postgres 10 parser and fingerprint version 2
  - This is a backwards-incompatible change in parser output format, although it should
    be relatively easy to update most programs. This can't be avoided since Postgres
    does not guarantee parse trees stay the same across versions


## 0.13.5    2017-10-26

* Update to libpg_query 9.5-1.7.1
  - Allow "$1 FROM $2" to be parsed (new with pg_stat_statements in Postgres 10)


## 0.13.4    2017-10-20

* Update to libpg_query 9.5-1.7.0
  - Fixes compilation old gcc before 4.6.0 [#73](https://github.com/lfittl/pg_query/issues/73)


## 0.13.3    2017-09-04

* Fix table detection for SELECTs that have sub-SELECTs without FROM clause [#69](https://github.com/lfittl/pg_query/issues/69)


## 0.13.2    2017-08-10

* Support table detection in sub-SELECTs in JOINs [#68](https://github.com/lfittl/pg_query/pull/65) [@seanmdick](https://github.com/seanmdick)
* Legacy ".parsetree" helper: Fix "Between" and "In" operator does not have "AEXPR" [#66](https://github.com/lfittl/pg_query/issues/66)
  * For new applications please use ".tree" method which uses the native structure
    returned from libpg_query which resembles Postgres node names more closely


## 0.13.1    2017-08-03

* Fix regression in 0.13.1 that broke ".tables" logic for COPY statements that
  don't have a target table (i.e. are reading out data vs copying in)


## 0.13.0    2017-07-30

* Introduce split between SELECT/DML/DDL for tables method [#65](https://github.com/lfittl/pg_query/pull/65) [@chrisfrommann](https://github.com/chrisfrommann)
  * Backwards compatible, use the new select_tables/dml_tables/ddl_tables to
    access the categorized table references
* Update libpg_query to 9.5-1.6.2
  * Update to Fingerprinting Version 1.3
    * Attributes to be ignored:
      * RangeVar.relname (if node also has RangeVar.relpersistence = "t")
    * Special cases: List nodes where parent field name is valuesLists
      * Follow same logic described for fromClause/targetList/cols/rexpr


## 0.12.1    2017-07-29

* Update libpg_query to 9.5-1.6.1
  * Update to Fingerprinting Version 1.2
    * Ignore portalname in DeclareCursorStmt, FetchStmt and ClosePortalStmt


## 0.12.0    2017-07-29

* Update libpg_query to 9.5-1.6.0
  * BREAKING CHANGE in PgQuery.normalize(..) output
  * This matches the change in the upcoming Postgres 10, and makes it easier to
    migrate applications to the new normalization format using $1..$N instead of ?


## 0.11.5    2017-07-09

* Deparse coldeflist [#64](https://github.com/lfittl/pg_query/pull/64) [@jcsjcs](https://github.com/jcsjcs)
* Use Integer class for checking integer instead of Fixnum [#62](https://github.com/lfittl/pg_query/pull/62) [@makimoto](https://github.com/makimoto)


## 0.11.4    2017-01-18

* Compatibility with Ruby 2.4 [#59](https://github.com/lfittl/pg_query/pull/59) [@merqlove](https://github.com/merqlove)
* Deparse varchar and numeric casts without arguments [#61](https://github.com/lfittl/pg_query/pull/61) [@jcsjcs](https://github.com/jcsjcs)


## 0.11.3    2016-12-06

* Update to newest libpg_query version (9.5-1.4.2)
  * Cut off fingerprints at 100 nodes deep to avoid excessive runtimes/memory
  * Fix warning on Linux due to missing asprintf include
* Improved deparsing [@jcsjcs](https://github.com/jcsjcs)
  * Float [#54](https://github.com/lfittl/pg_query/pull/54)
  * BETWEEN [#55](https://github.com/lfittl/pg_query/pull/55)
  * NULLIF [#56](https://github.com/lfittl/pg_query/pull/56)
  * SELECT NULL and BooleanTest [#57](https://github.com/lfittl/pg_query/pull/57)
* Fix build on BSD systems [#58](https://github.com/lfittl/pg_query/pull/58) [@myfreeweb](https://github.com/myfreeweb)


## 0.11.2    2016-06-27

* Update to newest libpg_query version (9.5-1.4.1)
  * This release makes sure we work correctly in threaded environments


## 0.11.1    2016-06-26

* Updated fingerprinting logic to version 1.1
  * Fixes an issue with UpdateStmt target lists being ignored
* Update to newest libpg_query version (9.5-1.4.0)


## 0.11.0    2016-06-22

* Improved table name analysis (#tables method)
  * Don't include CTE names, make them accessible as #cte_names instead [#52](https://github.com/lfittl/pg_query/issues/52)
  * Include table names in target list sub selects [#38](https://github.com/lfittl/pg_query/issues/38)
  * Add support for ORDER/GROUP BY, HAVING, and booleans in WHERE [#53](https://github.com/lfittl/pg_query/pull/53) [@jcoleman](https://github.com/jcoleman)
  * Fix parsing of DROP TYPE statements


## 0.10.0    2016-05-31

* Based on PostgreSQL 9.5.3
* Use LLVM extracted parser for significantly improved build times (via libpg_query)
* Deparsing Improvements
  * SET statements [#48](https://github.com/lfittl/pg_query/pull/48) [@Winslett](https://github.com/Winslett)
  * LIKE/NOT LIKE [#49](https://github.com/lfittl/pg_query/pull/49) [@Winslett](https://github.com/Winslett)
  * CREATE FUNCTION improvements [#50](https://github.com/lfittl/pg_query/pull/50) [@Winslett](https://github.com/Winslett)


## 0.9.2    2016-05-03

* Fix issue with A_CONST string values in `.parsetree` compatibility layer (Fixes [#47](https://github.com/lfittl/pg_query/issues/47))


## 0.9.1    2016-04-20

* Add support for Ruby 1.9 (Fixes [#44](https://github.com/lfittl/pg_query/issues/44))


## 0.9.0    2016-04-17

* Based on PostgreSQL 9.5.2
* NOTE: Output format for the parse tree has changed (backwards incompatible!),
        it is recommended you extensively test any direct reading/modification of
        the tree data in your own code
  * You can use the `.parsetree` translator method to ease the transition, note
    however that there are still a few incompatible changes
* New `.fingerprint` method (backwards incompatible as well), see https://github.com/lfittl/libpg_query/wiki/Fingerprinting
* Removes PostgreSQL source and tarball after build process has finished, to reduce
  diskspace requirements of the installed gem


## 0.8.0    2016-03-06

* Use fixed git version for libpg_query (PostgreSQL 9.4 based)
* NOTE: 0.8 will be the last series with the initial parse tree format, 0.9 will
        introduce a newer, more stable, but backwards incompatible parse tree format


## 0.7.2    2015-12-20

* Deparsing
  * Quote all column refs [#40](https://github.com/lfittl/pg_query/pull/40) [@avinoamr](https://github.com/avinoamr)
  * Quote all range vars [#43](https://github.com/lfittl/pg_query/pull/43) [@avinoamr](https://github.com/avinoamr)
  * Support for COUNT(DISTINCT ...) [#42](https://github.com/lfittl/pg_query/pull/42) [@avinoamr](https://github.com/avinoamr)


## 0.7.1    2015-11-17

* Abstracted parser access into libpg_query [#24](https://github.com/lfittl/pg_query/pull/35)
* libpg_query
  * Use UTF-8 encoding for parsing [#4](https://github.com/lfittl/libpg_query/pull/4) [@zhm](https://github.com/zhm)
  * Add type to A_CONST nodes[#5](https://github.com/lfittl/libpg_query/pull/5) [@zhm](https://github.com/zhm)


## 0.7.0    2015-10-17

* Restructure build process to use upstream tarballs [#35](https://github.com/lfittl/pg_query/pull/35)
  * Avoid bison/flex dependency to make deployment easier [#31](https://github.com/lfittl/pg_query/issues/31)
* Solve issues with deployments to Heroku [#32](https://github.com/lfittl/pg_query/issues/32)
* Deparsing
  * HAVING and FOR UPDATE [#36](https://github.com/lfittl/pg_query/pull/36) [@JackDanger](https://github.com/JackDanger)


## 0.6.4    2015-10-01

* Deparsing
  * Constraints & Interval Types [#28](https://github.com/lfittl/pg_query/pull/28) [@JackDanger](https://github.com/JackDanger)
  * Cross joins [#29](https://github.com/lfittl/pg_query/pull/29) [@mme](https://github.com/mme)
  * ALTER TABLE [#30](https://github.com/lfittl/pg_query/pull/30) [@JackDanger](https://github.com/JackDanger)
  * LIMIT and OFFSET [#33](https://github.com/lfittl/pg_query/pull/33) [@jcsjcs](https://github.com/jcsjcs)


## 0.6.3    2015-08-20

* Deparsing
  * COUNT(*) [@JackDanger](https://github.com/JackDanger)
  * Window clauses [Chris Martin](https://github.com/cmrtn)
  * CREATE TABLE/VIEW/FUNCTION [@JackDanger](https://github.com/JackDanger)
* Return exact location for parser errors [@JackDanger](https://github.com/JackDanger)


## 0.6.2    2015-08-06

* Speed up gem install by not generating rdoc/ri for the Postgres source


## 0.6.1    2015-08-06

* Deparsing: Support WITH clauses in INSERT/UPDATE/DELETE [@JackDanger](https://github.com/JackDanger)
* Make sure gemspec includes all necessary files


## 0.6.0    2015-08-05

* Deparsing (experimental)
  * Turns parse trees into SQL again
  * New truncate method to smartly truncate based on less important query parts
  * Thanks to [@mme](https://github.com/mme) & [@JackDanger](https://github.com/JackDanger) for their contributions
* Restructure extension C code
* Add table/filter columns support for CTEs
* Extract views as tables from CREATE/REFRESH VIEW
* Refactor code using generic treewalker
* fingerprint: Normalize IN lists
* param_refs: Fix length attribute in result


## 0.5.0    2015-03-26

* Query fingerprinting
* Filter columns (aka columns referenced in a query's WHERE clause)
* Parameter references: Returns all $1/$2/etc like references in the query with their location
* Remove dependency on active_support


## 0.4.1    2014-12-18

* Fix compilation of C extension
* Fix gemspec


## 0.4.0    2014-12-18

* Speed up build time by only building necessary objects
* PostgreSQL 9.4 parser


See git commit log for previous releases.
