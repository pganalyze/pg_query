require 'spec_helper'

describe PgQuery, "parsing" do
  it "should parse a simple query" do
    query = PgQuery.parse("SELECT 1")
    expect(query.parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}}, "location"=>7}}], "fromClause"=>nil, "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>"false", "larg"=>nil, "rarg"=>nil}}]
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
  end
  
  it "should set warnings for unknown node types" do
    query = PgQuery.parse("DEALLOCATE a739")
    expect(query.parsetree).to eq [{}]
    expect(query.warnings).to eq ["WARNING:  01000: could not dump unrecognized node type: 765"]
  end
  
  it "should parse empty queries" do
    query = PgQuery.parse("-- nothing")
    expect(query.parsetree).to eq []
    expect(query.warnings).to be_empty
  end
  
  it "should parse ALTER TABLE" do
    query = PgQuery.parse("ALTER TABLE test ADD PRIMARY KEY (gid)")
    expect(query.warnings).to eq []
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
                    "deferrable"=>"false",
                    "initdeferred"=>"false",
                    "location"=>21,
                    "contype"=>"PRIMARY_KEY",
                    "keys"=>["gid"],
                    "options"=>nil,
                    "indexname"=>nil,
                    "indexspace"=>nil}},
                "behavior"=>0,
                "missing_ok"=>"false"}}],
           "relkind"=>26,
           "missing_ok"=>"false"}}]
  end
  
  it "should parse SET" do
    query = PgQuery.parse("SET statement_timeout=0")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"SET"=>
          {"kind"=>0,
           "name"=>"statement_timeout",
           "args"=>[{"A_CONST"=>{"val"=>0, "location"=>22}}],
           "is_local"=>"false"}}]
  end
  
  it "should parse SHOW" do
    query = PgQuery.parse("SHOW work_mem")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"SHOW"=>{"name"=>"work_mem"}}]
  end
  
  it "should parse COPY" do
    query = PgQuery.parse("COPY test (id) TO stdout")
    expect(query.warnings).to eq []
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
           "is_from"=>"false",
           "is_program"=>"false",
           "filename"=>nil,
           "options"=>nil}}]
  end
  
  it "should parse DROP" do
    query = PgQuery.parse("drop table test123 cascade")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
          {"objects"=>[["test123"]],
           "arguments"=>nil,
           "removeType"=>26,
           "behavior"=>1,
           "missing_ok"=>"false",
           "concurrent"=>"false"}}]
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
    expect(query.parsetree).to eq [{"VACUUM"=>
          {"options"=>1,
           "freeze_min_age"=>"-1",
           "freeze_table_age"=>"-1",
           "relation"=>
            {"RANGEVAR"=>
              {"schemaname"=>nil,
               "relname"=>"my_table",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "alias"=>nil,
               "location"=>7}},
           "va_cols"=>nil,
           "multixact_freeze_min_age"=>"-1",
           "multixact_freeze_table_age"=>"-1"}}]
  end
  
  it "should parse EXPLAIN" do
    query = PgQuery.parse("EXPLAIN DELETE FROM test")
    expect(query.warnings).to eq []
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
               "all"=>"false",
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
               "skipData"=>"false"}},
           "relkind"=>26,
           "is_select_into"=>"false"}}]
  end
  
  it "should parse LOCK" do
    query = PgQuery.parse("LOCK TABLE public.schema_migrations IN ACCESS SHARE MODE")
    expect(query.warnings).to eq []
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
           "nowait"=>"false"}}]
  end
end

describe PgQuery, "normalized parsing" do
  it "should parse a normalized query" do
    query = PgQuery.parse("SELECT ? FROM x")
    expect(query.parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil,
                                    "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"PARAMREF"=>{"number"=>0, "location"=>7}}, "location"=>7}}],
                                    "fromClause"=>[{"RANGEVAR"=>{"schemaname"=>nil, "relname"=>"x", "inhOpt"=>2, "relpersistence"=>"p", "alias"=>nil, "location"=>14}}],
                                    "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>"false", "larg"=>nil, "rarg"=>nil}}]
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
                                                                  "setof"=>"false", "pct_type"=>"false", "typmods"=>nil,
                                                                  "typemod"=>"-1", "arrayBounds"=>nil, "location"=>7}},
                                                     "location"=>"-1"}})
  end
  
  it "should parse INTERVAL ? hour" do
    q = PgQuery.parse("SELECT INTERVAL ? hour")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"TYPECAST" => {"arg"=>{"PARAMREF" => {"number"=>0, "location"=>16}},
                                       "typeName"=>{"TYPENAME"=>{"names"=>["pg_catalog", "interval"], "typeOid"=>0,
                                                                 "setof"=>"false", "pct_type"=>"false",
                                                                 "typmods"=>[{"A_CONST"=>{"val"=>0, "location"=>"-1"}}],
                                                                 "typemod"=>"-1", "arrayBounds"=>nil, "location"=>7}},
                                       "location"=>"-1"}})
  end
  
  it "should parse 'a ? b' in target list" do
    q = PgQuery.parse("SELECT a ? b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq({"AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>7}},
                                                   "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>11}},
                                    "location"=>9}})
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
  
  it "should parse weird SET normalizations" do
    pending
    query = PgQuery.parse("SET CLIENT_ENCODING TO UTF?")
    expect(query.parsetree).not_to be_nil
  end
  
  it "should parse ?=ANY(..) constructs" do
    query = PgQuery.parse("SELECT 1 FROM x WHERE ?= ANY(z)")
    expect(query.parsetree).not_to be_nil
  end
  
  it "should parse complicated queries" do
    query = PgQuery.parse("BEGIN;SET statement_timeout=?;COMMIT;SELECT DISTINCT ON (nspname, seqname) nspname, seqname, quote_ident(nspname) || ? || quote_ident(seqname) AS safename, typname FROM ( SELECT depnsp.nspname, dep.relname as seqname, typname FROM pg_depend JOIN pg_class on classid = pg_class.oid JOIN pg_class dep on dep.oid = objid JOIN pg_namespace depnsp on depnsp.oid= dep.relnamespace JOIN pg_class refclass on refclass.oid = refclassid JOIN pg_class ref on ref.oid = refobjid JOIN pg_namespace refnsp on refnsp.oid = ref.relnamespace JOIN pg_attribute refattr ON (refobjid, refobjsubid) = (refattr.attrelid, refattr.attnum) JOIN pg_type ON refattr.atttypid = pg_type.oid WHERE pg_class.relname = ? AND refclass.relname = ? AND dep.relkind in (?) AND ref.relkind in (?) AND typname IN (?) UNION ALL SELECT nspname, seq.relname, typname FROM pg_attrdef JOIN pg_attribute ON (attrelid, attnum) = (adrelid, adnum) JOIN pg_type on pg_type.oid = atttypid JOIN pg_class rel ON rel.oid = attrelid JOIN pg_class seq ON seq.relname = regexp_replace(adsrc, $re$^nextval\\(?::regclass\\)$$re$, $$\\?$$) AND seq.relnamespace = rel.relnamespace JOIN pg_namespace nsp ON nsp.oid = seq.relnamespace WHERE adsrc ~ ? AND seq.relkind = ? AND typname IN (?) UNION ALL SELECT nspname, relname, CAST(? AS TEXT) FROM pg_class JOIN pg_namespace nsp ON nsp.oid = relnamespace WHERE relkind = ? ) AS seqs ORDER BY nspname, seqname, typname")
    expect(query.parsetree).not_to be_nil
  end
end