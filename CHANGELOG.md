# Changelog

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
