# Changelog

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
