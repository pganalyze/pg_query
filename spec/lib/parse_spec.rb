require 'spec_helper'

describe PgQuery, "parsing" do
  it "should parse a simple query" do
    query = PgQuery.parse("SELECT 1")
    expect(query.parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}}, "location"=>7}}], "fromClause"=>nil, "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>false, "larg"=>nil, "rarg"=>nil}}]
  end

  it "should handle errors" do
    expect { PgQuery.parse("SELECT 'ERR") }.to raise_error {|error|
      expect(error).to be_a(PgQuery::ParseError)
      expect(error.message).to eq "unterminated quoted string at or near \"'ERR\""
      expect(error.location).to eq 8 # 8th character in query string
    }
  end

  it "should parse real queries" do
    query = PgQuery.parse("SELECT memory_total_bytes, memory_free_bytes, memory_pagecache_bytes, memory_buffers_bytes, memory_applications_bytes, (memory_swap_total_bytes - memory_swap_free_bytes) AS swap, date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON (snapshot_id = s.id) WHERE s.database_id = $0 AND s.collected_at BETWEEN $0 AND $0 ORDER BY collected_at")
    expect(query.parsetree).not_to be_nil
    expect(query.tables).to eq ['snapshots', 'system_snapshots']
  end

  it "should parse empty queries" do
    query = PgQuery.parse("-- nothing")
    expect(query.parsetree).to eq []
    expect(query.tables).to eq []
    expect(query.warnings).to be_empty
  end

  it "should parse floats with leading dot" do
    q = PgQuery.parse("SELECT .1")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"A_CONST" => {"val"=>0.1, "location"=>7}})
  end

  it "should parse floats with trailing dot" do
    q = PgQuery.parse("SELECT 1.")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"A_CONST" => {"val"=>1.0, "location"=>7}})
  end

  it "should parse ALTER TABLE" do
    query = PgQuery.parse("ALTER TABLE test ADD PRIMARY KEY (gid)")
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

  it "should parse SET" do
    query = PgQuery.parse("SET statement_timeout=0")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"SET"=>
          {"kind"=>0,
           "name"=>"statement_timeout",
           "args"=>[{"A_CONST"=>{"val"=>0, "location"=>22}}],
           "is_local"=>false}}]
  end

  it "should parse SHOW" do
    query = PgQuery.parse("SHOW work_mem")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"SHOW"=>{"name"=>"work_mem"}}]
  end

  it "should parse COPY" do
    query = PgQuery.parse("COPY test (id) TO stdout")
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

  it "should parse DROP TABLE" do
    query = PgQuery.parse("drop table abc.test123 cascade")
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

  it "should parse COMMIT" do
    query = PgQuery.parse("COMMIT")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"TRANSACTION"=>{"kind"=>2, "options"=>nil, "gid"=>nil}}]
  end

  it "should parse CHECKPOINT" do
    query = PgQuery.parse("CHECKPOINT")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"CHECKPOINT"=>{}}]
  end

  it "should parse VACUUM" do
    query = PgQuery.parse("VACUUM my_table")
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

  it "should parse EXPLAIN" do
    query = PgQuery.parse("EXPLAIN DELETE FROM test")
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

  it "should parse SELECT INTO" do
    query = PgQuery.parse("CREATE TEMP TABLE test AS SELECT 1")
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

  it "should parse LOCK" do
    query = PgQuery.parse("LOCK TABLE public.schema_migrations IN ACCESS SHARE MODE")
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

  it 'should parse CREATE TABLE' do
    query = PgQuery.parse('CREATE TABLE test (a int4)')
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
             "fdwoptions"=>nil}}],
        "inhRelations"=>nil,
        "ofTypename"=>nil,
        "constraints"=>nil,
        "options"=>nil,
        "oncommit"=>0,
        "tablespacename"=>nil,
        "if_not_exists"=>false}}]
  end

  it 'should parse CREATE INDEX' do
    query = PgQuery.parse('CREATE INDEX testidx ON test USING gist (a)')
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

  it 'should parse CREATE SCHEMA' do
    query = PgQuery.parse('CREATE SCHEMA IF NOT EXISTS test AUTHORIZATION joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"CREATE SCHEMA"=>
       {"schemaname"=>"test",
        "authid"=>"joe",
        "schemaElts"=>nil,
        "if_not_exists"=>true}}]
  end

  it 'should parse CREATE VIEW' do
    query = PgQuery.parse('CREATE VIEW myview AS SELECT * FROM mytab')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytab']
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
      "options"=>nil}}]
  end

  it 'should parse CREATE RULE' do
    query = PgQuery.parse('CREATE RULE shoe_ins_protect AS ON INSERT TO shoe
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

  it 'should parse CREATE TRIGGER' do
    query = PgQuery.parse('CREATE TRIGGER check_update
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

  it 'should parse DROP SCHEMA' do
    query = PgQuery.parse('DROP SCHEMA myschema')
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

  it 'should parse DROP VIEW' do
    query = PgQuery.parse('DROP VIEW myview, myview2')
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

  it 'should parse DROP INDEX' do
    query = PgQuery.parse('DROP INDEX CONCURRENTLY myindex')
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

  it 'should parse DROP RULE' do
    query = PgQuery.parse('DROP RULE myrule ON mytable CASCADE')
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

  it 'should parse DROP TRIGGER' do
    query = PgQuery.parse('DROP TRIGGER IF EXISTS mytrigger ON mytable RESTRICT')
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

  it 'should parse GRANT' do
    query = PgQuery.parse('GRANT INSERT, UPDATE ON mytable TO myuser')
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

  it 'should parse REVOKE' do
    query = PgQuery.parse('REVOKE admins FROM joe')
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

  it 'should parse TRUNCATE' do
    query = PgQuery.parse('TRUNCATE bigtable, fattable RESTART IDENTITY')
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
end

def parse_expr(expr)
  q = PgQuery.parse("SELECT " + expr + " FROM x")
  expect(q.parsetree).not_to be_nil
  r = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
  expect(r["AEXPR"]).not_to be_nil
  r["AEXPR"]
end

describe PgQuery, "normalized parsing" do
  it "should parse a normalized query" do
    query = PgQuery.parse("SELECT ? FROM x")
    expect(query.parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil,
                                    "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"PARAMREF"=>{"number"=>0, "location"=>7}}, "location"=>7}}],
                                    "fromClause"=>[{"RANGEVAR"=>{"schemaname"=>nil, "relname"=>"x", "inhOpt"=>2, "relpersistence"=>"p", "alias"=>nil, "location"=>14}}],
                                    "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>false, "larg"=>nil, "rarg"=>nil}}]
    expect(query.query).to eq "SELECT ? FROM x"
  end

  it "should keep locations correct" do
    query = PgQuery.parse("SELECT ?, 123")
    targetlist = query.parsetree[0]["SELECT"]["targetList"]
    expect(targetlist[0]["RESTARGET"]["location"]).to eq 7
    expect(targetlist[1]["RESTARGET"]["location"]).to eq 10
  end

  it "should parse INTERVAL ?" do
    query = PgQuery.parse("SELECT INTERVAL ?")
    expect(query.parsetree).not_to be_nil
    targetlist = query.parsetree[0]["SELECT"]["targetList"]
    expect(targetlist[0]["RESTARGET"]["val"]).to eq({"TYPECAST" => {"arg"=>{"PARAMREF" => {"number"=>0, "location"=>16}},
                                                     "typeName"=>{"TYPENAME"=>{"names"=>["pg_catalog", "interval"], "typeOid"=>0,
                                                                  "setof"=>false, "pct_type"=>false, "typmods"=>nil,
                                                                  "typemod"=>-1, "arrayBounds"=>nil, "location"=>7}},
                                                     "location"=>-1}})
  end

  it "should parse INTERVAL ? hour" do
    q = PgQuery.parse("SELECT INTERVAL ? hour")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"TYPECAST" => {"arg"=>{"PARAMREF" => {"number"=>0, "location"=>16}},
                                       "typeName"=>{"TYPENAME"=>{"names"=>["pg_catalog", "interval"], "typeOid"=>0,
                                                                 "setof"=>false, "pct_type"=>false,
                                                                 "typmods"=>[{"A_CONST"=>{"val"=>0, "location"=>-1}}],
                                                                 "typemod"=>-1, "arrayBounds"=>nil, "location"=>7}},
                                       "location"=>-1}})
  end

  it "should parse INTERVAL (?) ?" do
    query = PgQuery.parse("SELECT INTERVAL (?) ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse 'a ? b' in target list" do
    q = PgQuery.parse("SELECT a ? b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>7}},
                                                   "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>11}},
                                    "location"=>9}})
  end

  it "should fail on '? 10' in target list" do
    # IMPORTANT: This is a difference of our patched parser from the main PostgreSQL parser
    #
    # This should be parsed as a left-unary operator, but we can't
    # support that due to keyword/function duality (e.g. JOIN)
    expect { PgQuery.parse("SELECT ? 10") }.to raise_error do |error|
      expect(error).to be_a(PgQuery::ParseError)
      expect(error.message).to eq "syntax error at or near \"10\""
    end
  end

  it "should mis-parse on '? a' in target list" do
    # IMPORTANT: This is a difference of our patched parser from the main PostgreSQL parser
    #
    # This is mis-parsed as a target list name (should be a column reference),
    # but we can't avoid that.
    q = PgQuery.parse("SELECT ? a")
    expect(q.parsetree).not_to be_nil
    restarget = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]
    expect(restarget).to eq({"name"=>"a", "indirection"=>nil,
                             "val"=>{"PARAMREF"=>{"number"=>0, "location"=>7}},
                             "location"=>7})
  end

  it "should parse 'a ?, b' in target list" do
    q = PgQuery.parse("SELECT a ?, b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>7}},
                                                   "rexpr"=>nil,
                                    "location"=>9}})
  end

  it "should parse 'a ? AND b' in where clause" do
    q = PgQuery.parse("SELECT * FROM x WHERE a ? AND b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["whereClause"]
    expect(expr).to eq({"AEXPR AND"=>{"lexpr"=>{"AEXPR"=>{"name"=>["?"],
                                                "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>22}},
                                                "rexpr"=>nil, "location"=>24}},
                                      "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>30}},
                                      "location"=>26}})
  end

  it "should parse 'JOIN y ON a = ? JOIN z ON c = d'" do
    # JOIN can be both a keyword and a function, this test is to make sure we treat it as a keyword in this case
    q = PgQuery.parse("SELECT * FROM x JOIN y ON a = ? JOIN z ON c = d")
    expect(q.parsetree).not_to be_nil
  end

  it "should parse 'a ? b' in where clause" do
    q = PgQuery.parse("SELECT * FROM x WHERE a ? b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["whereClause"]
    expect(expr).to eq({"AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>22}},
                                                   "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>26}},
                                    "location"=>24}})
  end

  it "should parse BETWEEN ? AND ?" do
    query = PgQuery.parse("SELECT x WHERE y BETWEEN ? AND ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse ?=?" do
    e = parse_expr("?=?")
    expect(e["name"]).to eq ["="]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?=x" do
    e = parse_expr("?=x")
    expect(e["name"]).to eq ["="]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["COLUMNREF"]).not_to be_nil
  end

  it "should parse x=?" do
    e = parse_expr("x=?")
    expect(e["name"]).to eq ["="]
    expect(e["lexpr"]["COLUMNREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?!=?" do
    e = parse_expr("?!=?")
    expect(e["name"]).to eq ["<>"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?!=x" do
    e = parse_expr("?!=x")
    expect(e["name"]).to eq ["<>"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["COLUMNREF"]).not_to be_nil
  end

  it "should parse x!=?" do
    e = parse_expr("x!=?")
    expect(e["name"]).to eq ["<>"]
    expect(e["lexpr"]["COLUMNREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?-?" do
    e = parse_expr("?-?")
    expect(e["name"]).to eq ["-"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?<?-?" do
    e = parse_expr("?<?-?")
    expect(e["name"]).to eq ["<"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["AEXPR"]).not_to be_nil
  end

  it "should parse ?+?" do
    e = parse_expr("?+?")
    expect(e["name"]).to eq ["+"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?*?" do
    e = parse_expr("?*?")
    expect(e["name"]).to eq ["*"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse ?/?" do
    e = parse_expr("?/?")
    expect(e["name"]).to eq ["/"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  # http://www.postgresql.org/docs/devel/static/functions-json.html
  # http://www.postgresql.org/docs/devel/static/hstore.html
  it "should parse hstore/JSON operators containing ?" do
    e = parse_expr("'{\"a\":1, \"b\":2}'::jsonb ? 'b'")
    expect(e["name"]).to eq ["?"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["A_CONST"]).not_to be_nil

    e = parse_expr("? ? ?")
    expect(e["name"]).to eq ["?"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("'{\"a\":1, \"b\":2, \"c\":3}'::jsonb ?| array['b', 'c']")
    expect(e["name"]).to eq ["?|"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["A_ARRAYEXPR"]).not_to be_nil

    e = parse_expr("? ?| ?")
    expect(e["name"]).to eq ["?|"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("'[\"a\", \"b\"]'::jsonb ?& array['a', 'b']")
    expect(e["name"]).to eq ["?&"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["A_ARRAYEXPR"]).not_to be_nil

    e = parse_expr("? ?& ?")
    expect(e["name"]).to eq ["?&"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  # http://www.postgresql.org/docs/devel/static/functions-geometry.html
  it "should parse geometric operators containing ?" do
    e = parse_expr("lseg '((-1,0),(1,0))' ?# box '((-2,-2),(2,2))'")
    expect(e["name"]).to eq ["?#"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("? ?# ?")
    expect(e["name"]).to eq ["?#"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("?- lseg '((-1,0),(1,0))'")
    expect(e["name"]).to eq ["?-"]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("?- ?")
    expect(e["name"]).to eq ["?-"]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("point '(1,0)' ?- point '(0,0)'")
    expect(e["name"]).to eq ["?-"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("? ?- ?")
    expect(e["name"]).to eq ["?-"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("?| lseg '((-1,0),(1,0))'")
    expect(e["name"]).to eq ["?|"]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("?| ?")
    expect(e["name"]).to eq ["?|"]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("point '(0,1)' ?| point '(0,0)'")
    expect(e["name"]).to eq ["?|"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("? ?| ?")
    expect(e["name"]).to eq ["?|"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("lseg '((0,0),(0,1))' ?-| lseg '((0,0),(1,0))'")
    expect(e["name"]).to eq ["?-|"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("? ?-| ?")
    expect(e["name"]).to eq ["?-|"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil

    e = parse_expr("lseg '((-1,0),(1,0))' ?|| lseg '((-1,2),(1,2))'")
    expect(e["name"]).to eq ["?||"]
    expect(e["lexpr"]["TYPECAST"]).not_to be_nil
    expect(e["rexpr"]["TYPECAST"]).not_to be_nil

    e = parse_expr("? ?|| ?")
    expect(e["name"]).to eq ["?||"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "should parse substituted pseudo keywords in extract()" do
    q = PgQuery.parse("SELECT extract(? from NOW())")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"FUNCCALL" => {"funcname"=>["pg_catalog", "date_part"],
                                       "args"=>[{"PARAMREF"=>{"number"=>0, "location"=>15}},
                                                {"FUNCCALL"=>{"funcname"=>["now"], "args"=>nil, "agg_order"=>nil,
                                                              "agg_star"=>false, "agg_distinct"=>false,
                                                              "func_variadic"=>false, "over"=>nil, "location"=>22}}],
                                       "agg_order"=>nil, "agg_star"=>false, "agg_distinct"=>false,
                                       "func_variadic"=>false, "over"=>nil, "location"=>7}})
  end

  it "should parse $1?" do
    query = PgQuery.parse("SELECT 1 FROM x WHERE x IN ($1?, $1?)")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET x = ?" do
    query = PgQuery.parse("SET statement_timeout = ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET x=?" do
    query = PgQuery.parse("SET statement_timeout=?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET TIME ZONE ?" do
    query = PgQuery.parse("SET TIME ZONE ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET SCHEMA ?" do
    query = PgQuery.parse("SET SCHEMA ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET ROLE ?" do
    query = PgQuery.parse("SET ROLE ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET SESSION AUTHORIZATION ?" do
    query = PgQuery.parse("SET SESSION AUTHORIZATION ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse SET encoding = UTF?" do
    query = PgQuery.parse("SET encoding = UTF?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse ?=ANY(..) constructs" do
    query = PgQuery.parse("SELECT 1 FROM x WHERE ?= ANY(z)")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse KEYWORD? constructs" do
    query = PgQuery.parse("select * from sessions where pid ilike? and id=? ")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse E?KEYWORD constructs" do
    query = PgQuery.parse("SELECT 1 FROM x WHERE nspname NOT LIKE E?AND nspname NOT LIKE ?")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse complicated queries" do
    query = PgQuery.parse("BEGIN;SET statement_timeout=?;COMMIT;SELECT DISTINCT ON (nspname, seqname) nspname, seqname, quote_ident(nspname) || ? || quote_ident(seqname) AS safename, typname FROM ( SELECT depnsp.nspname, dep.relname as seqname, typname FROM pg_depend JOIN pg_class on classid = pg_class.oid JOIN pg_class dep on dep.oid = objid JOIN pg_namespace depnsp on depnsp.oid= dep.relnamespace JOIN pg_class refclass on refclass.oid = refclassid JOIN pg_class ref on ref.oid = refobjid JOIN pg_namespace refnsp on refnsp.oid = ref.relnamespace JOIN pg_attribute refattr ON (refobjid, refobjsubid) = (refattr.attrelid, refattr.attnum) JOIN pg_type ON refattr.atttypid = pg_type.oid WHERE pg_class.relname = ? AND refclass.relname = ? AND dep.relkind in (?) AND ref.relkind in (?) AND typname IN (?) UNION ALL SELECT nspname, seq.relname, typname FROM pg_attrdef JOIN pg_attribute ON (attrelid, attnum) = (adrelid, adnum) JOIN pg_type on pg_type.oid = atttypid JOIN pg_class rel ON rel.oid = attrelid JOIN pg_class seq ON seq.relname = regexp_replace(adsrc, $re$^nextval\\(?::regclass\\)$$re$, $$\\?$$) AND seq.relnamespace = rel.relnamespace JOIN pg_namespace nsp ON nsp.oid = seq.relnamespace WHERE adsrc ~ ? AND seq.relkind = ? AND typname IN (?) UNION ALL SELECT nspname, relname, CAST(? AS TEXT) FROM pg_class JOIN pg_namespace nsp ON nsp.oid = relnamespace WHERE relkind = ? ) AS seqs ORDER BY nspname, seqname, typname")
    expect(query.parsetree).not_to be_nil
  end

  it "should parse cast(? as varchar(?))" do
    query = PgQuery.parse("SELECT cast(? as varchar(?))")
    expect(query.parsetree).not_to be_nil
  end
end
