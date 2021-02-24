require 'spec_helper'

describe PgQuery, '.parse' do
  it "parses a simple query" do
    query = described_class.parse("SELECT 1")
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::SELECT_STMT=>{described_class::TARGET_LIST_FIELD=>[{described_class::RES_TARGET=>{"val"=>{described_class::A_CONST=>{"val"=>{described_class::INTEGER => {"ival" => 1}}, "location"=>7}}, "location"=>7}}], "op"=>0}}}}]
  end

  it "handles errors" do
    expect { described_class.parse("SELECT 'ERR") }.to(raise_error do |error|
      expect(error).to be_a(described_class::ParseError)
      expect(error.message).to eq "unterminated quoted string at or near \"'ERR\" (scan.l:1162)"
      expect(error.location).to eq 8 # 8th character in query string
    end)
  end

  it 'returns JSON error due to too much nesting' do
    query_text = 'SELECT a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(b))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))'
    expect { described_class.parse(query_text) }.to(raise_error do |error|
      expect(error).to be_a(described_class::ParseError)
      expect(error.message).to start_with 'Failed to parse JSON'
    end)
  end

  it "parses real queries" do
    query = described_class.parse("SELECT memory_total_bytes, memory_free_bytes, memory_pagecache_bytes, memory_buffers_bytes, memory_applications_bytes, (memory_swap_total_bytes - memory_swap_free_bytes) AS swap, date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON (snapshot_id = s.id) WHERE s.database_id = $0 AND s.collected_at BETWEEN $0 AND $0 ORDER BY collected_at")
    expect(query.tree).not_to be_nil
    expect(query.tables).to eq ['snapshots', 'system_snapshots']
    expect(query.select_tables).to eq ['snapshots', 'system_snapshots']
  end

  it "parses empty queries" do
    query = described_class.parse("-- nothing")
    expect(query.tree).to eq []
    expect(query.tables).to eq []
    expect(query.warnings).to be_empty
  end

  it "parses floats with leading dot" do
    q = described_class.parse("SELECT .1")
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::A_CONST => {"val"=>{described_class::FLOAT => {"str" => ".1"}}, "location"=>7})
  end

  it "parses floats with trailing dot" do
    q = described_class.parse("SELECT 1.")
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::A_CONST => {"val"=>{described_class::FLOAT => {"str" => "1."}}, "location"=>7})
  end

  it 'parses bit strings (binary notation)' do
    q = described_class.parse("SELECT B'0101'")
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::A_CONST => {"val"=>{described_class::BIT_STRING => {"str" => "b0101"}}, "location"=>7})
  end

  it 'parses bit strings (hex notation)' do
    q = described_class.parse("SELECT X'EFFF'")
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::A_CONST => {"val"=>{described_class::BIT_STRING => {"str" => "xEFFF"}}, "location"=>7})
  end

  it "parses ALTER TABLE" do
    query = described_class.parse("ALTER TABLE test ADD PRIMARY KEY (gid)")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => {described_class::ALTER_TABLE_STMT=>
          {"relation"=>
            {described_class::RANGE_VAR=>
              {"relname"=>"test",
               "inh"=>true,
               "relpersistence"=>"p",
               "location"=>12}},
           "cmds"=>
            [{described_class::ALTER_TABLE_CMD=>
               {"subtype"=>14,
                "def"=>
                 {described_class::CONSTRAINT=>
                   {"contype"=>described_class::CONSTR_TYPE_PRIMARY,
                    "location"=>21,
                    "keys"=>[{"String" => {"str" => "gid"}}]}},
                "behavior"=>0}}],
           "relkind"=>described_class::OBJECT_TYPE_TABLE}}}}]
  end

  it "parses SET" do
    query = described_class.parse("SET statement_timeout=0")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::VARIABLE_SET_STMT=>
          {"kind"=>0,
           "name"=>"statement_timeout",
           "args"=>[{described_class::A_CONST=>{"val"=>{described_class::INTEGER => {"ival" => 0}}, "location"=>22}}]}}}}]
  end

  it "parses SHOW" do
    query = described_class.parse("SHOW work_mem")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::VARIABLE_SHOW_STMT=>{"name"=>"work_mem"}}}}]
  end

  it "parses COPY" do
    query = described_class.parse("COPY test (id) TO stdout")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::COPY_STMT=>
          {"relation"=>
            {described_class::RANGE_VAR=>
              {"relname"=>"test",
               "inh"=>true,
               "relpersistence"=>"p",
               "location"=>5}},
           "attlist"=>[{"String"=>{"str"=>"id"}}]}}}}]
  end

  it "parses DROP TABLE" do
    query = described_class.parse("drop table abc.test123 cascade")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['abc.test123']
    expect(query.ddl_tables).to eq ['abc.test123']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::DROP_STMT=>
          {"objects"=>[[{"String"=>{"str"=>"abc"}}, {"String"=>{"str"=>"test123"}}]],
           "removeType"=>described_class::OBJECT_TYPE_TABLE,
           "behavior"=>1}}}}]
  end

  it "parses COMMIT" do
    query = described_class.parse("COMMIT")
    expect(query.warnings).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::TRANSACTION_STMT=>{"kind"=>2}}}}]
  end

  it "parses CHECKPOINT" do
    query = described_class.parse("CHECKPOINT")
    expect(query.warnings).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CHECK_POINT_STMT=>{}}}}]
  end

  it "parses VACUUM" do
    query = described_class.parse("VACUUM my_table")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['my_table']
    expect(query.ddl_tables).to eq ['my_table']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::VACUUM_STMT=>
          {"options"=>1,
           "relation"=>
            {described_class::RANGE_VAR=>
              {"relname"=>"my_table",
               "inh"=>true,
               "relpersistence"=>"p",
               "location"=>7}}}}}}]
  end

  it "parses EXPLAIN" do
    query = described_class.parse("EXPLAIN DELETE FROM test")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::EXPLAIN_STMT=>
          {"query"=>
            {described_class::DELETE_STMT=>
              {"relation"=>
                {described_class::RANGE_VAR=>
                  {"relname"=>"test",
                   "inh"=>true,
                   "relpersistence"=>"p",
                   "location"=>20}}}}}}}}]
  end

  it "parses SELECT INTO" do
    query = described_class.parse("CREATE TEMP TABLE test AS SELECT 1")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_TABLE_AS_STMT=>
          {"query"=>
            {described_class::SELECT_STMT=>
              {described_class::TARGET_LIST_FIELD=>
                [{described_class::RES_TARGET=>
                   {"val"=>{described_class::A_CONST=>{"val"=>{described_class::INTEGER => {"ival" => 1}}, "location"=>33}},
                    "location"=>33}}],
               "op"=>0}},
           "into"=>
            {described_class::INTO_CLAUSE=>
              {"rel"=>
                {described_class::RANGE_VAR=>
                  {"relname"=>"test",
                   "inh"=>true,
                   "relpersistence"=>"t",
                   "location"=>18}},
               "onCommit"=>0}},
           "relkind"=>described_class::OBJECT_TYPE_TABLE}}}}]
  end

  it "parses LOCK" do
    query = described_class.parse("LOCK TABLE public.schema_migrations IN ACCESS SHARE MODE")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['public.schema_migrations']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::LOCK_STMT=>
          {"relations"=>
            [{described_class::RANGE_VAR=>
               {"schemaname"=>"public",
                "relname"=>"schema_migrations",
                "inh"=>true,
                "relpersistence"=>"p",
                "location"=>11}}],
           "mode"=>1}}}}]
  end

  it 'parses CREATE TABLE' do
    query = described_class.parse('CREATE TABLE test (a int4)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_STMT=>
       {"relation"=>
         {described_class::RANGE_VAR=>
           {"relname"=>"test",
            "inh"=>true,
            "relpersistence"=>"p",
            "location"=>13}},
        "tableElts"=>
         [{described_class::COLUMN_DEF=>
            {"colname"=>"a",
             "typeName"=>
              {described_class::TYPE_NAME=>
                {"names"=>[{"String"=>{"str"=>"int4"}}],
                 "typemod"=>-1,
                 "location"=>21}},
             "is_local"=>true,
             "location"=>19}}],
        "oncommit"=>0}}}}]
  end

  it 'parses CREATE TABLE WITH OIDS' do
    query = described_class.parse('CREATE TABLE test (a int4) WITH OIDS')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_STMT=>
       {"relation"=>
         {described_class::RANGE_VAR=>
           {"relname"=>"test",
            "inh"=>true,
            "relpersistence"=>"p",
            "location"=>13}},
        "tableElts"=>
         [{described_class::COLUMN_DEF=>
            {"colname"=>"a",
             "typeName"=>
              {described_class::TYPE_NAME=>
                {"names"=>[{"String"=>{"str"=>"int4"}}],
                 "typemod"=>-1,
                 "location"=>21}},
             "is_local"=>true,
             "location"=>19}}],
        "options"=> [{
          described_class::DEF_ELEM => {
            "defname"=>"oids",
            "arg"=>{"Integer"=>{"ival"=>1}},
            "defaction"=>0,
            "location"=>27
          }
        }],
        "oncommit"=>0}}}}]
  end

  it 'parses CREATE INDEX' do
    query = described_class.parse('CREATE INDEX testidx ON test USING gist (a)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::INDEX_STMT=>
       {"idxname"=>"testidx",
        "relation"=>
         {described_class::RANGE_VAR=>
           {"relname"=>"test",
            "inh"=>true,
            "relpersistence"=>"p",
            "location"=>24}},
        "accessMethod"=>"gist",
        "indexParams"=>
         [{described_class::INDEX_ELEM=>
            {"name"=>"a",
             "ordering"=>0,
             "nulls_ordering"=>0}}]}}}}]
  end

  it 'parses CREATE SCHEMA' do
    query = described_class.parse('CREATE SCHEMA IF NOT EXISTS test AUTHORIZATION joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_SCHEMA_STMT=>
       {"schemaname"=>"test",
        "authrole"=>{described_class::ROLE_SPEC=>{"roletype"=>0, "rolename"=>"joe", "location"=>47}},
        "if_not_exists"=>true}}}}]
  end

  it 'parses CREATE VIEW' do
    query = described_class.parse('CREATE VIEW myview AS SELECT * FROM mytab')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview', 'mytab']
    expect(query.ddl_tables).to eq ['myview']
    expect(query.select_tables).to eq ['mytab']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::VIEW_STMT=>
     {"view"=>
       {described_class::RANGE_VAR=>
         {"relname"=>"myview",
          "inh"=>true,
          "relpersistence"=>"p",
          "location"=>12}},
      "query"=>
       {described_class::SELECT_STMT=>
         {described_class::TARGET_LIST_FIELD=>
           [{described_class::RES_TARGET=>
              {"val"=>
                {described_class::COLUMN_REF=>{"fields"=>[{described_class::A_STAR=>{}}], "location"=>29}},
               "location"=>29}}],
          "fromClause"=>
           [{described_class::RANGE_VAR=>
              {"relname"=>"mytab",
               "inh"=>true,
               "relpersistence"=>"p",
               "location"=>36}}],
          "op"=>0}},
      "withCheckOption"=>0}}}}]
  end

  it 'parses REFRESH MATERIALIZED VIEW' do
    query = described_class.parse('REFRESH MATERIALIZED VIEW myview')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview']
    expect(query.ddl_tables).to eq ['myview']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::REFRESH_MAT_VIEW_STMT=>
   {"relation"=>
     {described_class::RANGE_VAR=>
       {"relname"=>"myview",
        "inh"=>true,
        "relpersistence"=>"p",
        "location"=>26}}}}}}]
  end

  it 'parses CREATE RULE' do
    query = described_class.parse('CREATE RULE shoe_ins_protect AS ON INSERT TO shoe
                           DO INSTEAD NOTHING')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['shoe']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::RULE_STMT=>
     {"relation"=>
       {described_class::RANGE_VAR=>
         {"relname"=>"shoe",
          "inh"=>true,
          "relpersistence"=>"p",
          "location"=>45}},
      "rulename"=>"shoe_ins_protect",
      "event"=>3,
      "instead"=>true}}}}]
  end

  it 'parses CREATE TRIGGER' do
    query = described_class.parse('CREATE TRIGGER check_update
                           BEFORE UPDATE ON accounts
                           FOR EACH ROW
                           EXECUTE PROCEDURE check_account_update()')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['accounts']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_TRIG_STMT=>
       {"trigname"=>"check_update",
        "relation"=>
         {described_class::RANGE_VAR=>
           {"relname"=>"accounts",
            "inh"=>true,
            "relpersistence"=>"p",
            "location"=>72}},
        "funcname"=>[{"String"=>{"str"=>"check_account_update"}}],
        "row"=>true,
        "timing"=>2,
        "events"=>16}}}}]
  end

  it 'parses DROP SCHEMA' do
    query = described_class.parse('DROP SCHEMA myschema')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::DROP_STMT=>
      {"objects"=>[{"String"=>{"str"=>"myschema"}}],
        "removeType"=>described_class::OBJECT_TYPE_SCHEMA,
        "behavior"=>0}}}}]
  end

  it 'parses DROP VIEW' do
    query = described_class.parse('DROP VIEW myview, myview2')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::DROP_STMT=>
      {"objects"=>[[{"String"=>{"str"=>"myview"}}], [{"String"=>{"str"=>"myview2"}}]],
        "removeType"=>described_class::OBJECT_TYPE_VIEW,
        "behavior"=>0}}}}]
  end

  it 'parses DROP INDEX' do
    query = described_class.parse('DROP INDEX CONCURRENTLY myindex')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::DROP_STMT=>
      {"objects"=>[[{"String"=>{"str"=>"myindex"}}]],
        "removeType"=>described_class::OBJECT_TYPE_INDEX,
        "behavior"=>0,
        "concurrent"=>true}}}}]
  end

  it 'parses DROP RULE' do
    query = described_class.parse('DROP RULE myrule ON mytable CASCADE')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::DROP_STMT=>
      {"objects"=>[[{"String"=>{"str"=>"mytable"}}, {"String"=>{"str"=>"myrule"}}]],
       "removeType"=>described_class::OBJECT_TYPE_RULE,
       "behavior"=>1}}}}]
  end

  it 'parses DROP TRIGGER' do
    query = described_class.parse('DROP TRIGGER IF EXISTS mytrigger ON mytable RESTRICT')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::DROP_STMT=>
      {"objects"=>[[{"String"=>{"str"=>"mytable"}}, {"String"=>{"str"=>"mytrigger"}}]],
       "removeType"=>described_class::OBJECT_TYPE_TRIGGER,
       "behavior"=>0,
       "missing_ok"=>true}}}}]
  end

  it 'parses GRANT' do
    query = described_class.parse('GRANT INSERT, UPDATE ON mytable TO myuser')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.ddl_tables).to eq ['mytable']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::GRANT_STMT=>
       {"is_grant"=>true,
        "targtype"=>0,
        "objtype"=>1,
        "objects"=>
         [{described_class::RANGE_VAR=>
            {"relname"=>"mytable",
             "inh"=>true,
             "relpersistence"=>"p",
             "location"=>24}}],
        "privileges"=>
         [{described_class::ACCESS_PRIV=>{"priv_name"=>"insert"}},
          {described_class::ACCESS_PRIV=>{"priv_name"=>"update"}}],
        "grantees"=>[{described_class::ROLE_SPEC=>{"roletype"=>0, "rolename"=>"myuser", "location"=>35}}],
        "behavior"=>0}}}}]
  end

  it 'parses REVOKE' do
    query = described_class.parse('REVOKE admins FROM joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::GRANT_ROLE_STMT=>
      {"granted_roles"=>[{described_class::ACCESS_PRIV=>{"priv_name"=>"admins"}}],
       "grantee_roles"=>[{described_class::ROLE_SPEC=>{"roletype"=>0, "rolename"=>"joe", "location"=>19}}],
       "behavior"=>0}}}}]
  end

  it 'parses TRUNCATE' do
    query = described_class.parse('TRUNCATE bigtable, fattable RESTART IDENTITY')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['bigtable', 'fattable']
    expect(query.ddl_tables).to eq ['bigtable', 'fattable']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::TRUNCATE_STMT=>
      {"relations"=>
         [{described_class::RANGE_VAR=>
             {"relname"=>"bigtable",
              "inh"=>true,
              "relpersistence"=>"p",
              "location"=>9}},
          {described_class::RANGE_VAR=>
             {"relname"=>"fattable",
              "inh"=>true,
              "relpersistence"=>"p",
              "location"=>19}}],
       "restart_seqs"=>true,
       "behavior"=>0}}}}]
  end

  it 'parses WITH' do
    query = described_class.parse('WITH a AS (SELECT * FROM x WHERE x.y = ? AND x.z = 1) SELECT * FROM a')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['x']
    expect(query.cte_names).to eq ['a']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::SELECT_STMT=>
   {described_class::TARGET_LIST_FIELD=>
     [{described_class::RES_TARGET=>
        {"val"=>{described_class::COLUMN_REF=>{"fields"=>[{described_class::A_STAR=>{}}], "location"=>61}},
         "location"=>61}}],
    "fromClause"=>
     [{described_class::RANGE_VAR=>
        {"relname"=>"a",
         "inh"=>true,
         "relpersistence"=>"p",
         "location"=>68}}],
    "withClause"=>
     {described_class::WITH_CLAUSE=>
       {"ctes"=>
         [{described_class::COMMON_TABLE_EXPR=>
            {"ctename"=>"a",
             "ctequery"=>
              {described_class::SELECT_STMT=>
                {described_class::TARGET_LIST_FIELD=>
                  [{described_class::RES_TARGET=>
                     {"val"=>
                       {described_class::COLUMN_REF=>
                         {"fields"=>[{described_class::A_STAR=>{}}], "location"=>18}},
                      "location"=>18}}],
                 "fromClause"=>
                  [{described_class::RANGE_VAR=>
                     {"relname"=>"x",
                      "inh"=>true,
                      "relpersistence"=>"p",
                      "location"=>25}}],
                 "whereClause"=>
                  {described_class::BOOL_EXPR=>
                    {"boolop"=>0,
                     "args"=>
                      [{described_class::A_EXPR=>
                        {"kind" => 0,
                         "name"=>[{"String"=>{"str"=>"="}}],
                         "lexpr"=>
                          {described_class::COLUMN_REF=>
                            {"fields"=>[{"String"=>{"str"=>"x"}}, {"String"=>{"str"=>"y"}}], "location"=>33}},
                         "rexpr"=>{described_class::PARAM_REF=>{"location"=>39}},
                         "location"=>37}},
                       {described_class::A_EXPR=>
                        {"kind" => 0,
                         "name"=>[{"String"=>{"str"=>"="}}],
                         "lexpr"=>
                          {described_class::COLUMN_REF=>
                            {"fields"=>[{"String"=>{"str"=>"x"}}, {"String"=>{"str"=>"z"}}], "location"=>45}},
                         "rexpr"=>{described_class::A_CONST=>{"val"=>{described_class::INTEGER => {"ival" => 1}}, "location"=>51}},
                         "location"=>49}}],
                     "location"=>41}},
                 "op"=>0}},
             "location"=>5}}]}},
    "op"=>0}}}}]
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
    expect(query.functions).to eq ['thing']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_FUNCTION_STMT=>
     {"replace"=>true,
      "funcname"=>[{"String"=>{"str"=>"thing"}}],
      "parameters"=>
       [{described_class::FUNCTION_PARAMETER=>
          {"name"=>"parameter_thing",
           "argType"=>
            {described_class::TYPE_NAME=>
              {"names"=>[{"String"=>{"str"=>"text"}}],
               "typemod"=>-1,
               "location"=>49}},
           "mode"=>105}}],
      "returnType"=>
       {described_class::TYPE_NAME=>
         {"names"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"int8"}}],
          "typemod"=>-1,
          "location"=>65}},
      "options"=>
       [{described_class::DEF_ELEM=>
          {"defname"=>"as",
           "arg"=>
           [{"String"=>
            {"str"=>"\nDECLARE\n        local_thing_id BIGINT := 0;\nBEGIN\n        SELECT thing_id INTO local_thing_id FROM thing_map\n        WHERE\n                thing_map_field = parameter_thing\n        ORDER BY 1 LIMIT 1;\n\n        IF NOT FOUND THEN\n                local_thing_id = 0;\n        END IF;\n        RETURN local_thing_id;\nEND;\n"}}],
           "defaction"=>0,
           "location"=>72}},
        {described_class::DEF_ELEM=>
          {"defname"=>"language",
           "arg"=>{"String"=>{"str"=>"plpgsql"}},
           "defaction"=>0,
           "location"=>407}},
        {described_class::DEF_ELEM=>
          {"defname"=>"volatility",
           "arg"=>{"String"=>{"str"=>"stable"}},
           "defaction"=>0,
           "location"=>424}}]}}}}]
  end

  it 'parses table functions' do
    query = described_class.parse("CREATE FUNCTION getfoo(int) RETURNS TABLE (f1 int) AS '
    SELECT * FROM foo WHERE fooid = $1;
' LANGUAGE SQL")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.functions).to eq ['getfoo']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { described_class::CREATE_FUNCTION_STMT=>
    {"funcname"=>[{"String"=>{"str"=>"getfoo"}}],
    "parameters"=>
     [{described_class::FUNCTION_PARAMETER=>
        {"argType"=>
          {described_class::TYPE_NAME=>
            {"names"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"int4"}}],
             "typemod"=>-1,
             "location"=>23}},
         "mode"=>105}},
      {described_class::FUNCTION_PARAMETER=>
        {"name"=>"f1",
         "argType"=>
          {described_class::TYPE_NAME=>
            {"names"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"int4"}}],
             "typemod"=>-1,
             "location"=>46}},
         "mode"=>116}}],
    "returnType"=>
     {described_class::TYPE_NAME=>
       {"names"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"int4"}}],
        "setof"=>true,
        "typemod"=>-1,
        "location"=>36}},
    "options"=>
     [{described_class::DEF_ELEM=>
        {"defname"=>"as",
         "arg"=>[{"String"=>{"str"=>"\n    SELECT * FROM foo WHERE fooid = $1;\n"}}],
         "defaction"=>0,
         "location"=>51}},
      {described_class::DEF_ELEM=>
        {"defname"=>"language",
         "arg"=>{"String"=>{"str"=>"sql"}},
         "defaction"=>0,
         "location"=>98}}]}}}}]
  end

  it 'correctly finds created functions' do
    query = described_class.parse(<<-SQL)
      CREATE OR REPLACE FUNCTION testfunc(x integer) RETURNS integer AS $$
        BEGIN
          RETURN x
        END;
      $$ LANGUAGE plpgsql STABLE;
      SELECT testfunc(1);
    SQL
    expect(query.tables).to eq []
    expect(query.warnings).to eq []
    expect(query.functions).to eq ['testfunc', 'testfunc']
    expect(query.ddl_functions).to eq ['testfunc']
    expect(query.call_functions).to eq ['testfunc']
  end

  it 'correctly finds called functions' do
    query = described_class.parse(<<-SQL)
      SELECT testfunc(1);
    SQL
    expect(query.tables).to eq []
    expect(query.warnings).to eq []
    expect(query.functions).to eq ['testfunc']
    expect(query.ddl_functions).to eq []
    expect(query.call_functions).to eq ['testfunc']
  end

  it 'correctly finds dropped functions' do
    query = described_class.parse(<<-SQL)
      DROP FUNCTION IF EXISTS testfunc(x integer);
    SQL
    expect(query.tables).to eq []
    expect(query.warnings).to eq []
    expect(query.functions).to eq ['testfunc']
    expect(query.ddl_functions).to eq ['testfunc']
    expect(query.call_functions).to eq []
  end

  it 'correctly finds renamed functions' do
    query = described_class.parse(<<-SQL)
      ALTER FUNCTION testfunc(integer) RENAME TO testfunc2;
    SQL
    expect(query.tables).to eq []
    expect(query.warnings).to eq []
    expect(query.functions).to eq ['testfunc', 'testfunc2']
    expect(query.ddl_functions).to eq ['testfunc', 'testfunc2']
    expect(query.call_functions).to eq []
  end

  # https://github.com/lfittl/pg_query/issues/38
  it 'correctly finds nested tables in select clause' do
    query = described_class.parse("select u.email, (select count(*) from enrollments e where e.user_id = u.id) as num_enrollments from users u")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'enrollments']
    expect(query.select_tables).to eq ['users', 'enrollments']
  end

  # https://github.com/lfittl/pg_query/issues/52
  it 'correctly separates CTE names from table names' do
    query = described_class.parse("WITH cte_name AS (SELECT 1) SELECT * FROM table_name, cte_name")
    expect(query.cte_names).to eq ['cte_name']
    expect(query.tables).to eq ['table_name']
    expect(query.select_tables).to eq ['table_name']
  end

  it 'correctly finds nested tables in from clause' do
    query = described_class.parse("select u.* from (select * from users) u")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users']
    expect(query.select_tables).to eq ['users']
  end

  it 'correctly finds nested tables in where clause' do
    query = described_class.parse("select users.id from users where 1 = (select count(*) from user_roles)")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
    expect(query.select_tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds tables in a select that has sub-selects without from clause' do
    query = described_class.parse('SELECT * FROM pg_catalog.pg_class c JOIN (SELECT 17650 AS oid UNION ALL SELECT 17663 AS oid) vals ON c.oid = vals.oid')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ["pg_catalog.pg_class"]
    expect(query.select_tables).to eq ["pg_catalog.pg_class"]
    expect(query.filter_columns).to eq [["pg_catalog.pg_class", "oid"], ["vals", "oid"]]
  end

  it 'traverse boolean expressions in where clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      where users.id IN (
        select user_roles.user_id
        from user_roles
      ) and (users.created_at between '2016-06-01' and '2016-06-30')
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the order by clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      order by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the order by clause with multiple entries' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      order by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      ) asc, (
        select max(user_logins.role_id)
        from user_logins
        where user_logins.user_id = users.id
      ) desc
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles', 'user_logins']
  end

  it 'correctly finds nested tables in the group by clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the group by clause with multiple entries' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      ), (
        select max(user_logins.role_id)
        from user_logins
        where user_logins.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles', 'user_logins']
  end

  it 'correctly finds nested tables in the having clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by users.id
      having 1 > (
        select count(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the having clause with a boolean expression' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by users.id
      having true and 1 > (
        select count(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in a subselect on a join' do
    query = described_class.parse(<<-SQL)
      select foo.*
      from foo
      join ( select * from bar ) b
      on b.baz = foo.quux
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['foo', 'bar']
  end

  it 'does not list CTEs as tables after a union select' do
    query = described_class.parse(<<-SQL)
      with cte_a as (
        select * from table_a
      ), cte_b as (
        select * from table_b
      )

      select id from table_c
      left join cte_b on
        table_c.id = cte_b.c_id
      union
      select * from cte_a
    SQL
    expect(query.tables).to match_array(['table_a', 'table_b', 'table_c'])
    expect(query.cte_names).to match_array(['cte_a', 'cte_b'])
  end

  describe 'parsing INSERT' do
    it 'finds the table inserted into' do
      query = described_class.parse(<<-SQL)
        insert into users(pk, name) values (1, 'bob');
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to eq(['users'])
    end

    it 'finds tables in being selected from for insert' do
      query = described_class.parse(<<-SQL)
        insert into users(pk, name) select pk, name from other_users;
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end

    it 'finds tables in a CTE' do
      query = described_class.parse(<<-SQL)
        with cte as (
          select pk, name from other_users
        )
        insert into users(pk, name) select * from cte;
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end
  end

  describe 'parsing UPDATE' do
    it 'finds the table updateed into' do
      query = described_class.parse(<<-SQL)
        update users set name = 'bob';
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to eq(['users'])
    end

    it 'finds tables in a sub-select' do
      query = described_class.parse(<<-SQL)
        update users set name = (select name from other_users limit 1);
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end

    it 'finds tables in a CTE' do
      query = described_class.parse(<<-SQL)
        with cte as (
          select name from other_users limit 1
        )
        update users set name = (select name from cte);
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end
  end

  it 'handles DROP TYPE' do
    query = described_class.parse("DROP TYPE IF EXISTS repack.pk_something")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree).to eq [{
      described_class::RAW_STMT => {
        described_class::STMT_FIELD =>
        {
          "DropStmt"=>
          {
            "objects"=>
            [{"TypeName"=>
                {"names"=>
                  [{"String"=>{"str"=>"repack"}},
                   {"String"=>{"str"=>"pk_something"}}],
                 "typemod"=>-1,
                 "location"=>20}}],
           "removeType"=>described_class::OBJECT_TYPE_TYPE,
           "behavior"=>0,
           "missing_ok"=>true
          }
        }
      }
    }]
  end

  it 'handles COPY' do
    query = described_class.parse("COPY (SELECT test FROM abc) TO STDOUT WITH (FORMAT 'csv')")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['abc']
    expect(query.tree).to eq [{ described_class::RAW_STMT => { described_class::STMT_FIELD => { 'CopyStmt' =>
      { 'query' =>
        { 'SelectStmt' =>
        { 'targetList' =>
            [{ 'ResTarget' =>
               { 'val' =>
                 { 'ColumnRef' =>
                   { 'fields' => [{ 'String' => { 'str' => 'test' } }], 'location' => 13 } },
                 'location' => 13 } }],
          'fromClause' =>
            [{ 'RangeVar' =>
               { 'relname' => 'abc',
                 'inh' => true,
                 'relpersistence' => 'p',
                 'location' => 23 } }],
          'op' => 0 } },
        'options' =>
        [{ 'DefElem' =>
           { 'defname' => 'format',
             'arg' => { 'String' => { 'str' => 'csv' } },
             'defaction' => 0,
             'location' => 44 } }] } }}}]
  end

  describe 'parsing CREATE TABLE AS' do
    it 'finds tables in the subquery' do
      query = described_class.parse(<<-SQL)
        CREATE TABLE foo AS
          SELECT * FROM bar;
      SQL
      expect(query.tables).to eq(['foo', 'bar'])
      expect(query.ddl_tables).to eq(['foo'])
      expect(query.select_tables).to eq(['bar'])
    end

    it 'finds tables in the subquery with UNION' do
      query = described_class.parse(<<-SQL)
        CREATE TABLE foo AS
          SELECT id FROM bar UNION SELECT id from baz;
      SQL

      expect(query.tables).to eq(['foo', 'bar', 'baz'])
      expect(query.ddl_tables).to eq(['foo'])
      expect(query.select_tables).to eq(['bar', 'baz'])
    end
  end
end
