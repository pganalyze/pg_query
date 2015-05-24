require 'spec_helper'

describe PgQuery, '.parse' do
  it "parses a simple query" do
    query = described_class.parse("SELECT 1")
    expect(query.parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}}, "location"=>7}}], "fromClause"=>nil, "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>false, "larg"=>nil, "rarg"=>nil}}]
  end

  it "handles errors" do
    expect { described_class.parse("SELECT 'ERR") }.to raise_error {|error|
      expect(error).to be_a(described_class::ParseError)
      expect(error.message).to eq "unterminated quoted string at or near \"'ERR\""
      expect(error.location).to eq 8 # 8th character in query string
    }
  end

  it "parses real queries" do
    query = described_class.parse("SELECT memory_total_bytes, memory_free_bytes, memory_pagecache_bytes, memory_buffers_bytes, memory_applications_bytes, (memory_swap_total_bytes - memory_swap_free_bytes) AS swap, date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON (snapshot_id = s.id) WHERE s.database_id = $0 AND s.collected_at BETWEEN $0 AND $0 ORDER BY collected_at")
    expect(query.parsetree).not_to be_nil
    expect(query.tables).to eq ['snapshots', 'system_snapshots']
  end

  it "parses empty queries" do
    query = described_class.parse("-- nothing")
    expect(query.parsetree).to eq []
    expect(query.tables).to eq []
    expect(query.warnings).to be_empty
  end

  it "parses floats with leading dot" do
    q = described_class.parse("SELECT .1")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("A_CONST" => {"val"=>0.1, "location"=>7})
  end

  it "parses floats with trailing dot" do
    q = described_class.parse("SELECT 1.")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("A_CONST" => {"val"=>1.0, "location"=>7})
  end

  it "parses ALTER TABLE" do
    query = described_class.parse("ALTER TABLE test ADD PRIMARY KEY (gid)")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"ALTER TABLE"=>
          {"relation"=>
            {"RANGEVAR"=>
              {"schemaname"=>nil,
               "relname"=>"test",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "alias"=>nil,
               "location"=>12}},
           "cmds"=>
            [{"ALTER TABLE CMD"=>
               {"subtype"=>14,
                "name"=>nil,
                "def"=>
                 {"CONSTRAINT"=>
                   {"conname"=>nil,
                    "deferrable"=>false,
                    "initdeferred"=>false,
                    "location"=>21,
                    "contype"=>"PRIMARY_KEY",
                    "keys"=>["gid"],
                    "options"=>nil,
                    "indexname"=>nil,
                    "indexspace"=>nil}},
                "behavior"=>0,
                "missing_ok"=>false}}],
           "relkind"=>26,
           "missing_ok"=>false}}]
  end

  it "parses SET" do
    query = described_class.parse("SET statement_timeout=0")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"SET"=>
          {"kind"=>0,
           "name"=>"statement_timeout",
           "args"=>[{"A_CONST"=>{"val"=>0, "location"=>22}}],
           "is_local"=>false}}]
  end

  it "parses SHOW" do
    query = described_class.parse("SHOW work_mem")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"SHOW"=>{"name"=>"work_mem"}}]
  end

  it "parses COPY" do
    query = described_class.parse("COPY test (id) TO stdout")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"COPY"=>
          {"relation"=>
            {"RANGEVAR"=>
              {"schemaname"=>nil,
               "relname"=>"test",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "alias"=>nil,
               "location"=>5}},
           "query"=>nil,
           "attlist"=>["id"],
           "is_from"=>false,
           "is_program"=>false,
           "filename"=>nil,
           "options"=>nil}}]
  end

  it "parses DROP TABLE" do
    query = described_class.parse("drop table abc.test123 cascade")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['abc.test123']
    expect(query.parsetree).to eq [{"DROP"=>
          {"objects"=>[["abc", "test123"]],
           "arguments"=>nil,
           "removeType"=>26,
           "behavior"=>1,
           "missing_ok"=>false,
           "concurrent"=>false}}]
  end

  it "parses COMMIT" do
    query = described_class.parse("COMMIT")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"TRANSACTION"=>{"kind"=>2, "options"=>nil, "gid"=>nil}}]
  end

  it "parses CHECKPOINT" do
    query = described_class.parse("CHECKPOINT")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"CHECKPOINT"=>{}}]
  end

  it "parses VACUUM" do
    query = described_class.parse("VACUUM my_table")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['my_table']
    expect(query.parsetree).to eq [{"VACUUM"=>
          {"options"=>1,
           "freeze_min_age"=>-1,
           "freeze_table_age"=>-1,
           "relation"=>
            {"RANGEVAR"=>
              {"schemaname"=>nil,
               "relname"=>"my_table",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "alias"=>nil,
               "location"=>7}},
           "va_cols"=>nil,
           "multixact_freeze_min_age"=>-1,
           "multixact_freeze_table_age"=>-1}}]
  end

  it "parses EXPLAIN" do
    query = described_class.parse("EXPLAIN DELETE FROM test")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"EXPLAIN"=>
          {"query"=>
            {"DELETE FROM"=>
              {"relation"=>
                {"RANGEVAR"=>
                  {"schemaname"=>nil,
                   "relname"=>"test",
                   "inhOpt"=>2,
                   "relpersistence"=>"p",
                   "alias"=>nil,
                   "location"=>20}},
               "usingClause"=>nil,
               "whereClause"=>nil,
               "returningList"=>nil,
               "withClause"=>nil}},
           "options"=>nil}}]
  end

  it "parses SELECT INTO" do
    query = described_class.parse("CREATE TEMP TABLE test AS SELECT 1")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"CREATE TABLE AS"=>
          {"query"=>
            {"SELECT"=>
              {"distinctClause"=>nil,
               "intoClause"=>nil,
               "targetList"=>
                [{"RESTARGET"=>
                   {"name"=>nil,
                    "indirection"=>nil,
                    "val"=>{"A_CONST"=>{"val"=>1, "location"=>33}},
                    "location"=>33}}],
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
               "all"=>false,
               "larg"=>nil,
               "rarg"=>nil}},
           "into"=>
            {"INTOCLAUSE"=>
              {"rel"=>
                {"RANGEVAR"=>
                  {"schemaname"=>nil,
                   "relname"=>"test",
                   "inhOpt"=>2,
                   "relpersistence"=>"t",
                   "alias"=>nil,
                   "location"=>18}},
               "colNames"=>nil,
               "options"=>nil,
               "onCommit"=>0,
               "tableSpaceName"=>nil,
               "viewQuery"=>nil,
               "skipData"=>false}},
           "relkind"=>26,
           "is_select_into"=>false}}]
  end

  it "parses LOCK" do
    query = described_class.parse("LOCK TABLE public.schema_migrations IN ACCESS SHARE MODE")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['public.schema_migrations']
    expect(query.parsetree).to eq [{"LOCK"=>
          {"relations"=>
            [{"RANGEVAR"=>
               {"schemaname"=>"public",
                "relname"=>"schema_migrations",
                "inhOpt"=>2,
                "relpersistence"=>"p",
                "alias"=>nil,
                "location"=>11}}],
           "mode"=>1,
           "nowait"=>false}}]
  end

  it 'parses CREATE TABLE' do
    query = described_class.parse('CREATE TABLE test (a int4)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"CREATESTMT"=>
       {"relation"=>
         {"RANGEVAR"=>
           {"schemaname"=>nil,
            "relname"=>"test",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "alias"=>nil,
            "location"=>13}},
        "tableElts"=>
         [{"COLUMNDEF"=>
            {"colname"=>"a",
             "typeName"=>
              {"TYPENAME"=>
                {"names"=>["int4"],
                 "typeOid"=>0,
                 "setof"=>false,
                 "pct_type"=>false,
                 "typmods"=>nil,
                 "typemod"=>-1,
                 "arrayBounds"=>nil,
                 "location"=>21}},
             "inhcount"=>0,
             "is_local"=>true,
             "is_not_null"=>false,
             "is_from_type"=>false,
             "storage"=>nil,
             "raw_default"=>nil,
             "cooked_default"=>nil,
             "collClause"=>nil,
             "collOid"=>0,
             "constraints"=>nil,
             "fdwoptions"=>nil,
             "location"=>19}}],
        "inhRelations"=>nil,
        "ofTypename"=>nil,
        "constraints"=>nil,
        "options"=>nil,
        "oncommit"=>0,
        "tablespacename"=>nil,
        "if_not_exists"=>false}}]
  end

  it 'parses CREATE TABLE WITH OIDS' do
    query = described_class.parse('CREATE TABLE test (a int4) WITH OIDS')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"CREATESTMT"=>
       {"relation"=>
         {"RANGEVAR"=>
           {"schemaname"=>nil,
            "relname"=>"test",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "alias"=>nil,
            "location"=>13}},
        "tableElts"=>
         [{"COLUMNDEF"=>
            {"colname"=>"a",
             "typeName"=>
              {"TYPENAME"=>
                {"names"=>["int4"],
                 "typeOid"=>0,
                 "setof"=>false,
                 "pct_type"=>false,
                 "typmods"=>nil,
                 "typemod"=>-1,
                 "arrayBounds"=>nil,
                 "location"=>21}},
             "inhcount"=>0,
             "is_local"=>true,
             "is_not_null"=>false,
             "is_from_type"=>false,
             "storage"=>nil,
             "raw_default"=>nil,
             "cooked_default"=>nil,
             "collClause"=>nil,
             "collOid"=>0,
             "constraints"=>nil,
             "fdwoptions"=>nil,
             "location"=>19}}],
        "inhRelations"=>nil,
        "ofTypename"=>nil,
        "constraints"=>nil,
        "options"=> [{"DEFELEM"=> {"defnamespace"=>nil, "defname"=>"oids", "arg"=>1, "defaction"=>0}}],
        "oncommit"=>0,
        "tablespacename"=>nil,
        "if_not_exists"=>false}}]
  end

  it 'parses CREATE INDEX' do
    query = described_class.parse('CREATE INDEX testidx ON test USING gist (a)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"INDEXSTMT"=>
       {"idxname"=>"testidx",
        "relation"=>
         {"RANGEVAR"=>
           {"schemaname"=>nil,
            "relname"=>"test",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "alias"=>nil,
            "location"=>24}},
        "accessMethod"=>"gist",
        "tableSpace"=>nil,
        "indexParams"=>
         [{"INDEXELEM"=>
            {"name"=>"a",
             "expr"=>nil,
             "indexcolname"=>nil,
             "collation"=>nil,
             "opclass"=>nil,
             "ordering"=>0,
             "nulls_ordering"=>0}}],
        "options"=>nil,
        "whereClause"=>nil,
        "excludeOpNames"=>nil,
        "idxcomment"=>nil,
        "indexOid"=>0,
        "oldNode"=>0,
        "unique"=>false,
        "primary"=>false,
        "isconstraint"=>false,
        "deferrable"=>false,
        "initdeferred"=>false,
        "concurrent"=>false}}]
  end

  it 'parses CREATE SCHEMA' do
    query = described_class.parse('CREATE SCHEMA IF NOT EXISTS test AUTHORIZATION joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"CREATE SCHEMA"=>
       {"schemaname"=>"test",
        "authid"=>"joe",
        "schemaElts"=>nil,
        "if_not_exists"=>true}}]
  end

  it 'parses CREATE VIEW' do
    query = described_class.parse('CREATE VIEW myview AS SELECT * FROM mytab')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview', 'mytab']
    expect(query.parsetree).to eq [{"VIEWSTMT"=>
     {"view"=>
       {"RANGEVAR"=>
         {"schemaname"=>nil,
          "relname"=>"myview",
          "inhOpt"=>2,
          "relpersistence"=>"p",
          "alias"=>nil,
          "location"=>12}},
      "aliases"=>nil,
      "query"=>
       {"SELECT"=>
         {"distinctClause"=>nil,
          "intoClause"=>nil,
          "targetList"=>
           [{"RESTARGET"=>
              {"name"=>nil,
               "indirection"=>nil,
               "val"=>
                {"COLUMNREF"=>{"fields"=>[{"A_STAR"=>{}}], "location"=>29}},
               "location"=>29}}],
          "fromClause"=>
           [{"RANGEVAR"=>
              {"schemaname"=>nil,
               "relname"=>"mytab",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "alias"=>nil,
               "location"=>36}}],
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
          "rarg"=>nil}},
      "replace"=>false,
      "options"=>nil,
      "withCheckOption"=>0}}]
  end

  it 'parses REFRESH MATERIALIZED VIEW' do
    query = described_class.parse('REFRESH MATERIALIZED VIEW myview')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview']
    expect(query.parsetree).to eq [{"REFRESHMATVIEWSTMT"=>
   {"concurrent"=>false,
    "skipData"=>false,
    "relation"=>
     {"RANGEVAR"=>
       {"schemaname"=>nil,
        "relname"=>"myview",
        "inhOpt"=>2,
        "relpersistence"=>"p",
        "alias"=>nil,
        "location"=>26}}}}]
  end

  it 'parses CREATE RULE' do
    query = described_class.parse('CREATE RULE shoe_ins_protect AS ON INSERT TO shoe
                           DO INSTEAD NOTHING')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['shoe']
    expect(query.parsetree).to eq [{"RULESTMT"=>
     {"relation"=>
       {"RANGEVAR"=>
         {"schemaname"=>nil,
          "relname"=>"shoe",
          "inhOpt"=>2,
          "relpersistence"=>"p",
          "alias"=>nil,
          "location"=>45}},
      "rulename"=>"shoe_ins_protect",
      "whereClause"=>nil,
      "event"=>3,
      "instead"=>true,
      "actions"=>nil,
      "replace"=>false}}]
  end

  it 'parses CREATE TRIGGER' do
    query = described_class.parse('CREATE TRIGGER check_update
                           BEFORE UPDATE ON accounts
                           FOR EACH ROW
                           EXECUTE PROCEDURE check_account_update()')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['accounts']
    expect(query.parsetree).to eq [{"CREATETRIGSTMT"=>
       {"trigname"=>"check_update",
        "relation"=>
         {"RANGEVAR"=>
           {"schemaname"=>nil,
            "relname"=>"accounts",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "alias"=>nil,
            "location"=>72}},
        "funcname"=>["check_account_update"],
        "args"=>nil,
        "row"=>true,
        "timing"=>2,
        "events"=>16,
        "columns"=>nil,
        "whenClause"=>nil,
        "isconstraint"=>false,
        "deferrable"=>false,
        "initdeferred"=>false,
        "constrrel"=>nil}}]
  end

  it 'parses DROP SCHEMA' do
    query = described_class.parse('DROP SCHEMA myschema')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["myschema"]],
        "arguments"=>nil,
        "removeType"=>24,
        "behavior"=>0,
        "missing_ok"=>false,
        "concurrent"=>false}}]
  end

  it 'parses DROP VIEW' do
    query = described_class.parse('DROP VIEW myview, myview2')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["myview"], ["myview2"]],
        "arguments"=>nil,
        "removeType"=>34,
        "behavior"=>0,
        "missing_ok"=>false,
        "concurrent"=>false}}]
  end

  it 'parses DROP INDEX' do
    query = described_class.parse('DROP INDEX CONCURRENTLY myindex')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["myindex"]],
        "arguments"=>nil,
        "removeType"=>15,
        "behavior"=>0,
        "missing_ok"=>false,
        "concurrent"=>true}}]
  end

  it 'parses DROP RULE' do
    query = described_class.parse('DROP RULE myrule ON mytable CASCADE')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["mytable", "myrule"]],
       "arguments"=>nil,
       "removeType"=>23,
       "behavior"=>1,
       "missing_ok"=>false,
       "concurrent"=>false}}]
  end

  it 'parses DROP TRIGGER' do
    query = described_class.parse('DROP TRIGGER IF EXISTS mytrigger ON mytable RESTRICT')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["mytable", "mytrigger"]],
       "arguments"=>nil,
       "removeType"=>28,
       "behavior"=>0,
       "missing_ok"=>true,
       "concurrent"=>false}}]
  end

  it 'parses GRANT' do
    query = described_class.parse('GRANT INSERT, UPDATE ON mytable TO myuser')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.parsetree).to eq [{"GRANTSTMT"=>
       {"is_grant"=>true,
        "targtype"=>0,
        "objtype"=>1,
        "objects"=>
         [{"RANGEVAR"=>
            {"schemaname"=>nil,
             "relname"=>"mytable",
             "inhOpt"=>2,
             "relpersistence"=>"p",
             "alias"=>nil,
             "location"=>24}}],
        "privileges"=>
         [{"ACCESSPRIV"=>{"priv_name"=>"insert", "cols"=>nil}},
          {"ACCESSPRIV"=>{"priv_name"=>"update", "cols"=>nil}}],
        "grantees"=>[{"PRIVGRANTEE"=>{"rolname"=>"myuser"}}],
        "grant_option"=>false,
        "behavior"=>0}}]
  end

  it 'parses REVOKE' do
    query = described_class.parse('REVOKE admins FROM joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"GRANTROLESTMT"=>
      {"granted_roles"=>[{"ACCESSPRIV"=>{"priv_name"=>"admins", "cols"=>nil}}],
       "grantee_roles"=>["joe"],
       "is_grant"=>false,
       "admin_opt"=>false,
       "grantor"=>nil,
       "behavior"=>0}}]
  end

  it 'parses TRUNCATE' do
    query = described_class.parse('TRUNCATE bigtable, fattable RESTART IDENTITY')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['bigtable', 'fattable']
    expect(query.parsetree).to eq [{"TRUNCATE"=>
      {"relations"=>
         [{"RANGEVAR"=>
             {"schemaname"=>nil,
              "relname"=>"bigtable",
              "inhOpt"=>2,
              "relpersistence"=>"p",
              "alias"=>nil,
              "location"=>9}},
          {"RANGEVAR"=>
             {"schemaname"=>nil,
              "relname"=>"fattable",
              "inhOpt"=>2,
              "relpersistence"=>"p",
              "alias"=>nil,
              "location"=>19}}],
       "restart_seqs"=>true,
       "behavior"=>0}}]
  end

  it 'parses WITH' do
    query = described_class.parse('WITH a AS (SELECT * FROM x WHERE x.y = ? AND x.z = 1) SELECT * FROM a')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['a', 'x']
    expect(query.parsetree).to eq [{"SELECT"=>
   {"distinctClause"=>nil,
    "intoClause"=>nil,
    "targetList"=>
     [{"RESTARGET"=>
        {"name"=>nil,
         "indirection"=>nil,
         "val"=>{"COLUMNREF"=>{"fields"=>[{"A_STAR"=>{}}], "location"=>61}},
         "location"=>61}}],
    "fromClause"=>
     [{"RANGEVAR"=>
        {"schemaname"=>nil,
         "relname"=>"a",
         "inhOpt"=>2,
         "relpersistence"=>"p",
         "alias"=>nil,
         "location"=>68}}],
    "whereClause"=>nil,
    "groupClause"=>nil,
    "havingClause"=>nil,
    "windowClause"=>nil,
    "valuesLists"=>nil,
    "sortClause"=>nil,
    "limitOffset"=>nil,
    "limitCount"=>nil,
    "lockingClause"=>nil,
    "withClause"=>
     {"WITHCLAUSE"=>
       {"ctes"=>
         [{"COMMONTABLEEXPR"=>
            {"ctename"=>"a",
             "aliascolnames"=>nil,
             "ctequery"=>
              {"SELECT"=>
                {"distinctClause"=>nil,
                 "intoClause"=>nil,
                 "targetList"=>
                  [{"RESTARGET"=>
                     {"name"=>nil,
                      "indirection"=>nil,
                      "val"=>
                       {"COLUMNREF"=>
                         {"fields"=>[{"A_STAR"=>{}}], "location"=>18}},
                      "location"=>18}}],
                 "fromClause"=>
                  [{"RANGEVAR"=>
                     {"schemaname"=>nil,
                      "relname"=>"x",
                      "inhOpt"=>2,
                      "relpersistence"=>"p",
                      "alias"=>nil,
                      "location"=>25}}],
                 "whereClause"=>
                  {"AEXPR AND"=>
                    {"lexpr"=>
                      {"AEXPR"=>
                        {"name"=>["="],
                         "lexpr"=>
                          {"COLUMNREF"=>
                            {"fields"=>["x", "y"], "location"=>33}},
                         "rexpr"=>{"PARAMREF"=>{"number"=>0, "location"=>39}},
                         "location"=>37}},
                     "rexpr"=>
                      {"AEXPR"=>
                        {"name"=>["="],
                         "lexpr"=>
                          {"COLUMNREF"=>
                            {"fields"=>["x", "z"], "location"=>45}},
                         "rexpr"=>{"A_CONST"=>{"val"=>1, "location"=>51}},
                         "location"=>49}},
                     "location"=>41}},
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
                 "rarg"=>nil}},
             "location"=>5,
             "cterecursive"=>false,
             "cterefcount"=>0,
             "ctecolnames"=>nil,
             "ctecoltypes"=>nil,
             "ctecoltypmods"=>nil,
             "ctecolcollations"=>nil}}],
        "recursive"=>false,
        "location"=>0}},
    "op"=>0,
    "all"=>false,
    "larg"=>nil,
    "rarg"=>nil}}]
  end

  it 'parses multi-line function definitions' do
    query = described_class.parse('CREATE OR REPLACE FUNCTION thing(parameter_thing text)
  RETURNS bigint AS
$BODY$
DECLARE
        local_thing_id BIGINT := 0;
BEGIN
        SELECT thing_id INTO local_thing_id FROM thing_map
        WHERE
                thing_map_field = parameter_thing
        ORDER BY 1 LIMIT 1;

        IF NOT FOUND THEN
                local_thing_id = 0;
        END IF;
        RETURN local_thing_id;
END;
$BODY$
  LANGUAGE plpgsql STABLE')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"CREATEFUNCTIONSTMT"=>
     {"replace"=>true,
      "funcname"=>["thing"],
      "parameters"=>
       [{"FUNCTIONPARAMETER"=>
          {"name"=>"parameter_thing",
           "argType"=>
            {"TYPENAME"=>
              {"names"=>["text"],
               "typeOid"=>0,
               "setof"=>false,
               "pct_type"=>false,
               "typmods"=>nil,
               "typemod"=>-1,
               "arrayBounds"=>nil,
               "location"=>49}},
           "mode"=>105,
           "defexpr"=>nil}}],
      "returnType"=>
       {"TYPENAME"=>
         {"names"=>["pg_catalog", "int8"],
          "typeOid"=>0,
          "setof"=>false,
          "pct_type"=>false,
          "typmods"=>nil,
          "typemod"=>-1,
          "arrayBounds"=>nil,
          "location"=>65}},
      "options"=>
       [{"DEFELEM"=>
          {"defnamespace"=>nil,
           "defname"=>"as",
           "arg"=>
            ["\nDECLARE\n        local_thing_id BIGINT := 0;\nBEGIN\n        SELECT thing_id INTO local_thing_id FROM thing_map\n        WHERE\n                thing_map_field = parameter_thing\n        ORDER BY 1 LIMIT 1;\n\n        IF NOT FOUND THEN\n                local_thing_id = 0;\n        END IF;\n        RETURN local_thing_id;\nEND;\n"],
           "defaction"=>0}},
        {"DEFELEM"=>
          {"defnamespace"=>nil,
           "defname"=>"language",
           "arg"=>"plpgsql",
           "defaction"=>0}},
        {"DEFELEM"=>
          {"defnamespace"=>nil,
           "defname"=>"volatility",
           "arg"=>"stable",
           "defaction"=>0}}],
      "withClause"=>nil}}]
  end

  it 'parses table functions' do
    query = described_class.parse("CREATE FUNCTION getfoo(int) RETURNS TABLE (f1 int) AS '
    SELECT * FROM foo WHERE fooid = $1;
' LANGUAGE SQL")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"CREATEFUNCTIONSTMT"=>
    {"replace"=>false,
    "funcname"=>["getfoo"],
    "parameters"=>
     [{"FUNCTIONPARAMETER"=>
        {"name"=>nil,
         "argType"=>
          {"TYPENAME"=>
            {"names"=>["pg_catalog", "int4"],
             "typeOid"=>0,
             "setof"=>false,
             "pct_type"=>false,
             "typmods"=>nil,
             "typemod"=>-1,
             "arrayBounds"=>nil,
             "location"=>23}},
         "mode"=>105,
         "defexpr"=>nil}},
      {"FUNCTIONPARAMETER"=>
        {"name"=>"f1",
         "argType"=>
          {"TYPENAME"=>
            {"names"=>["pg_catalog", "int4"],
             "typeOid"=>0,
             "setof"=>false,
             "pct_type"=>false,
             "typmods"=>nil,
             "typemod"=>-1,
             "arrayBounds"=>nil,
             "location"=>46}},
         "mode"=>116,
         "defexpr"=>nil}}],
    "returnType"=>
     {"TYPENAME"=>
       {"names"=>["pg_catalog", "int4"],
        "typeOid"=>0,
        "setof"=>true,
        "pct_type"=>false,
        "typmods"=>nil,
        "typemod"=>-1,
        "arrayBounds"=>nil,
        "location"=>36}},
    "options"=>
     [{"DEFELEM"=>
        {"defnamespace"=>nil,
         "defname"=>"as",
         "arg"=>["\n    SELECT * FROM foo WHERE fooid = $1;\n"],
         "defaction"=>0}},
      {"DEFELEM"=>
        {"defnamespace"=>nil,
         "defname"=>"language",
         "arg"=>"sql",
         "defaction"=>0}}],
    "withClause"=>nil}}]
  end
end
