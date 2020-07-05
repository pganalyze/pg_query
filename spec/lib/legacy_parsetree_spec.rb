require 'spec_helper'

# .parsetree is the compatibility layer to ease transitions from 0.7 and earlier versions of pg_query
describe PgQuery, '#parsetree' do
  it "parses a simple query" do
    query = described_class.parse("SELECT 1")
    expect(query.parsetree).to eq [{"SELECT"=>{"targetList"=>[{"RESTARGET"=>{"val"=>{"A_CONST"=>{"type" => "integer", "val"=>1, "location"=>7}}, "location"=>7}}], "op"=>0}}]
  end

  it "parses empty queries" do
    query = described_class.parse("-- nothing")
    expect(query.parsetree).to eq []
  end

  it "parses floats with leading dot" do
    q = described_class.parse("SELECT .1")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("A_CONST" => {"type" => "float", "val"=>0.1, "location"=>7})
  end

  it "parses floats with trailing dot" do
    q = described_class.parse("SELECT 1.")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("A_CONST" => {"type" => "float", "val"=>1.0, "location"=>7})
  end

  it 'parses bit strings (binary notation)' do
    q = described_class.parse("SELECT B'0101'")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("A_CONST" => {"type" => "bitstring", "val"=>"b0101", "location"=>7})
  end

  it 'parses bit strings (hex notation)' do
    q = described_class.parse("SELECT X'EFFF'")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("A_CONST" => {"type" => "bitstring", "val"=>"xEFFF", "location"=>7})
  end

  it "parses ALTER TABLE" do
    query = described_class.parse("ALTER TABLE test ADD PRIMARY KEY (gid)")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"ALTER TABLE"=>
          {"relation"=>
            {"RANGEVAR"=>
              {"relname"=>"test",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "location"=>12}},
           "cmds"=>
            [{"ALTER TABLE CMD"=>
               {"subtype"=>described_class::OBJECT_TYPE_EXTENSION,
                "def"=>
                 {"CONSTRAINT"=>
                   {"contype"=>"PRIMARY_KEY",
                    "location"=>21,
                    "keys"=>["gid"]}},
                "behavior"=>0}}],
           "relkind"=>described_class::OBJECT_TYPE_TABLE}}]
  end

  it "parses SET" do
    query = described_class.parse("SET statement_timeout=0")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"SET"=>
          {"kind"=>0,
           "name"=>"statement_timeout",
           "args"=>[{"A_CONST"=>{"type"=>"integer", "val"=>0, "location"=>22}}]}}]
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
              {"relname"=>"test",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "location"=>5}},
           "attlist"=>["id"]}}]
  end

  it "parses DROP TABLE" do
    query = described_class.parse("drop table abc.test123 cascade")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['abc.test123']
    expect(query.parsetree).to eq [{"DROP"=>
          {"objects"=>[["abc", "test123"]],
           "removeType"=>described_class::OBJECT_TYPE_TABLE,
           "behavior"=>1}}]
  end

  it "parses COMMIT" do
    query = described_class.parse("COMMIT")
    expect(query.warnings).to eq []
    expect(query.parsetree).to eq [{"TRANSACTION"=>{"kind"=>2}}]
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
           "relation"=>
            {"RANGEVAR"=>
              {"relname"=>"my_table",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "location"=>7}}}}]
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
                  {"relname"=>"test",
                   "inhOpt"=>2,
                   "relpersistence"=>"p",
                   "location"=>20}}}}}}]
  end

  it "parses SELECT INTO" do
    query = described_class.parse("CREATE TEMP TABLE test AS SELECT 1")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"CREATE TABLE AS"=>
          {"query"=>
            {"SELECT"=>
              {"targetList"=>
                [{"RESTARGET"=>
                   {"val"=>{"A_CONST"=>{"val"=>1, "location"=>33, "type" => "integer"}},
                    "location"=>33}}],
               "op"=>0}},
           "into"=>
            {"INTOCLAUSE"=>
              {"rel"=>
                {"RANGEVAR"=>
                  {"relname"=>"test",
                   "inhOpt"=>2,
                   "relpersistence"=>"t",
                   "location"=>18}},
               "onCommit"=>0}},
           "relkind"=>described_class::OBJECT_TYPE_TABLE}}]
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
                "location"=>11}}],
           "mode"=>1}}]
  end

  it 'parses CREATE TABLE' do
    query = described_class.parse('CREATE TABLE test (a int4)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"CREATESTMT"=>
       {"relation"=>
         {"RANGEVAR"=>
           {"relname"=>"test",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "location"=>13}},
        "tableElts"=>
         [{"COLUMNDEF"=>
            {"colname"=>"a",
             "typeName"=>
              {"TYPENAME"=>
                {"names"=>["int4"],
                 "typemod"=>-1,
                 "location"=>21}},
             "is_local"=>true,
             "location"=>19}}],
        "oncommit"=>0}}]
  end

  it 'parses CREATE TABLE WITH OIDS' do
    query = described_class.parse('CREATE TABLE test (a int4) WITH OIDS')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"CREATESTMT"=>
       {"relation"=>
         {"RANGEVAR"=>
           {"relname"=>"test",
            "relpersistence"=>"p",
            "location"=>13,
            "inhOpt"=>2}},
        "tableElts"=>
         [{"COLUMNDEF"=>
            {"colname"=>"a",
             "typeName"=>
              {"TYPENAME"=>
                {"names"=>["int4"],
                 "typemod"=>-1,
                 "location"=>21}},
             "is_local"=>true,
             "location"=>19}}],
        "options"=> [{"DEFELEM"=> {"defname"=>"oids", "arg"=>1, "defaction"=>0, "location"=>27}}],
        "oncommit"=>0}}]
  end

  it 'parses CREATE INDEX' do
    query = described_class.parse('CREATE INDEX testidx ON test USING gist (a)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.parsetree).to eq [{"INDEXSTMT"=>
       {"idxname"=>"testidx",
        "relation"=>
         {"RANGEVAR"=>
           {"relname"=>"test",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "location"=>24}},
        "accessMethod"=>"gist",
        "indexParams"=>
         [{"INDEXELEM"=>
            {"name"=>"a",
             "ordering"=>0,
             "nulls_ordering"=>0}}]}}]
  end

  it 'parses CREATE SCHEMA' do
    query = described_class.parse('CREATE SCHEMA IF NOT EXISTS test AUTHORIZATION joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"CREATE SCHEMA"=>
       {"schemaname"=>"test",
        "authrole"=>{"ROLESPEC"=>{"roletype"=>0, "rolename"=>"joe", "location"=>47}},
        "if_not_exists"=>true}}]
  end

  it 'parses CREATE VIEW' do
    query = described_class.parse('CREATE VIEW myview AS SELECT * FROM mytab')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview', 'mytab']
    expect(query.parsetree).to eq [{"VIEWSTMT"=>
     {"view"=>
       {"RANGEVAR"=>
         {"relname"=>"myview",
          "inhOpt"=>2,
          "relpersistence"=>"p",
          "location"=>12}},
      "query"=>
       {"SELECT"=>
         {"targetList"=>
           [{"RESTARGET"=>
              {"val"=>
                {"COLUMNREF"=>{"fields"=>[{"A_STAR"=>{}}], "location"=>29}},
               "location"=>29}}],
          "fromClause"=>
           [{"RANGEVAR"=>
              {"relname"=>"mytab",
               "inhOpt"=>2,
               "relpersistence"=>"p",
               "location"=>36}}],
          "op"=>0}},
      "withCheckOption"=>0}}]
  end

  it 'parses REFRESH MATERIALIZED VIEW' do
    query = described_class.parse('REFRESH MATERIALIZED VIEW myview')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview']
    expect(query.parsetree).to eq [{"REFRESHMATVIEWSTMT"=>
   {"relation"=>
     {"RANGEVAR"=>
       {"relname"=>"myview",
        "inhOpt"=>2,
        "relpersistence"=>"p",
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
         {"relname"=>"shoe",
          "inhOpt"=>2,
          "relpersistence"=>"p",
          "location"=>45}},
      "rulename"=>"shoe_ins_protect",
      "event"=>3,
      "instead"=>true}}]
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
           {"relname"=>"accounts",
            "inhOpt"=>2,
            "relpersistence"=>"p",
            "location"=>72}},
        "funcname"=>["check_account_update"],
        "row"=>true,
        "timing"=>2,
        "events"=>16}}]
  end

  it 'parses DROP SCHEMA' do
    query = described_class.parse('DROP SCHEMA myschema')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["myschema"]],
        "removeType"=>described_class::OBJECT_TYPE_SCHEMA,
        "behavior"=>0}}]
  end

  it 'parses DROP VIEW' do
    query = described_class.parse('DROP VIEW myview, myview2')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["myview"], ["myview2"]],
        "removeType"=>described_class::OBJECT_TYPE_VIEW,
        "behavior"=>0}}]
  end

  it 'parses DROP INDEX' do
    query = described_class.parse('DROP INDEX CONCURRENTLY myindex')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["myindex"]],
        "removeType"=>described_class::OBJECT_TYPE_INDEX,
        "behavior"=>0,
        "concurrent"=>true}}]
  end

  it 'parses DROP RULE' do
    query = described_class.parse('DROP RULE myrule ON mytable CASCADE')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["mytable", "myrule"]],
       "removeType"=>described_class::OBJECT_TYPE_RULE,
       "behavior"=>1}}]
  end

  it 'parses DROP TRIGGER' do
    query = described_class.parse('DROP TRIGGER IF EXISTS mytrigger ON mytable RESTRICT')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.parsetree).to eq [{"DROP"=>
      {"objects"=>[["mytable", "mytrigger"]],
       "removeType"=>described_class::OBJECT_TYPE_TRIGGER,
       "behavior"=>0,
       "missing_ok"=>true}}]
  end

  it 'parses GRANT' do
    query = described_class.parse('GRANT INSERT, UPDATE ON mytable TO myuser')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.parsetree).to eq [{"GRANTSTMT"=>
       {"is_grant"=>true,
        "targtype"=>0,
        "objtype"=>described_class::OBJECT_TYPE_TABLE,
        "objects"=>
         [{"RANGEVAR"=>
            {"relname"=>"mytable",
             "inhOpt"=>2,
             "relpersistence"=>"p",
             "location"=>24}}],
        "privileges"=>
         [{"ACCESSPRIV"=>{"priv_name"=>"insert"}},
          {"ACCESSPRIV"=>{"priv_name"=>"update"}}],
        "grantees"=>[{"ROLESPEC"=>{"roletype"=>0, "rolename"=>"myuser", "location"=>35}}],
        "behavior"=>0}}]
  end

  it 'parses REVOKE' do
    query = described_class.parse('REVOKE admins FROM joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"GRANTROLESTMT"=>
      {"granted_roles"=>[{"ACCESSPRIV"=>{"priv_name"=>"admins"}}],
       "grantee_roles"=>[{"ROLESPEC"=>{"roletype"=>0, "rolename"=>"joe", "location"=>19}}],
       "behavior"=>0}}]
  end

  it 'parses TRUNCATE' do
    query = described_class.parse('TRUNCATE bigtable, fattable RESTART IDENTITY')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['bigtable', 'fattable']
    expect(query.parsetree).to eq [{"TRUNCATE"=>
      {"relations"=>
         [{"RANGEVAR"=>
             {"relname"=>"bigtable",
              "inhOpt"=>2,
              "relpersistence"=>"p",
              "location"=>9}},
          {"RANGEVAR"=>
             {"relname"=>"fattable",
              "inhOpt"=>2,
              "relpersistence"=>"p",
              "location"=>19}}],
       "restart_seqs"=>true,
       "behavior"=>0}}]
  end

  it 'parses WITH' do
    query = described_class.parse('WITH a AS (SELECT * FROM x WHERE x.y = ? AND x.z = 1) SELECT * FROM a')
    expect(query.parsetree).to eq [{"SELECT"=>
   {"targetList"=>
     [{"RESTARGET"=>
        {"val"=>{"COLUMNREF"=>{"fields"=>[{"A_STAR"=>{}}], "location"=>61}},
         "location"=>61}}],
    "fromClause"=>
     [{"RANGEVAR"=>
        {"relname"=>"a",
         "inhOpt"=>2,
         "relpersistence"=>"p",
         "location"=>68}}],
    "withClause"=>
     {"WITHCLAUSE"=>
       {"ctes"=>
         [{"COMMONTABLEEXPR"=>
            {"ctename"=>"a",
             "ctequery"=>
              {"SELECT"=>
                {"targetList"=>
                  [{"RESTARGET"=>
                     {"val"=>
                       {"COLUMNREF"=>
                         {"fields"=>[{"A_STAR"=>{}}], "location"=>18}},
                      "location"=>18}}],
                 "fromClause"=>
                  [{"RANGEVAR"=>
                     {"relname"=>"x",
                      "inhOpt"=>2,
                      "relpersistence"=>"p",
                      "location"=>25}}],
                 "whereClause"=>
                  {"BOOLEXPR"=>
                    {"boolop" => 0,
                     "args"=>
                      [{"AEXPR"=>
                        {"name"=>["="],
                         "lexpr"=>
                          {"COLUMNREF"=>
                            {"fields"=>["x", "y"], "location"=>33}},
                         "rexpr"=>{"PARAMREF"=>{"location"=>39}},
                         "location"=>37}},
                       {"AEXPR"=>
                        {"name"=>["="],
                         "lexpr"=>
                          {"COLUMNREF"=>
                            {"fields"=>["x", "z"], "location"=>45}},
                         "rexpr"=>{"A_CONST"=>{"type"=>"integer", "val"=>1, "location"=>51}},
                         "location"=>49}}],
                     "location"=>41}},
                 "op"=>0}},
             "location"=>5}}]}},
    "op"=>0}}]
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
               "typemod"=>-1,
               "location"=>49}},
           "mode"=>105}}],
      "returnType"=>
       {"TYPENAME"=>
         {"names"=>["pg_catalog", "int8"],
          "typemod"=>-1,
          "location"=>65}},
      "options"=>
       [{"DEFELEM"=>
          {"defname"=>"as",
           "arg"=>
            ["\nDECLARE\n        local_thing_id BIGINT := 0;\nBEGIN\n        SELECT thing_id INTO local_thing_id FROM thing_map\n        WHERE\n                thing_map_field = parameter_thing\n        ORDER BY 1 LIMIT 1;\n\n        IF NOT FOUND THEN\n                local_thing_id = 0;\n        END IF;\n        RETURN local_thing_id;\nEND;\n"],
           "defaction"=>0,
           "location"=>72}},
        {"DEFELEM"=>
          {"defname"=>"language",
           "arg"=>"plpgsql",
           "defaction"=>0,
           "location"=>407}},
        {"DEFELEM"=>
          {"defname"=>"volatility",
           "arg"=>"stable",
           "defaction"=>0,
           "location"=>424}}]}}]
  end

  it 'parses table functions' do
    query = described_class.parse("CREATE FUNCTION getfoo(int) RETURNS TABLE (f1 int) AS '
    SELECT * FROM foo WHERE fooid = $1;
' LANGUAGE SQL")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"CREATEFUNCTIONSTMT"=>
    {"funcname"=>["getfoo"],
    "parameters"=>
     [{"FUNCTIONPARAMETER"=>
        {"argType"=>
          {"TYPENAME"=>
            {"names"=>["pg_catalog", "int4"],
             "typemod"=>-1,
             "location"=>23}},
         "mode"=>105}},
      {"FUNCTIONPARAMETER"=>
        {"name"=>"f1",
         "argType"=>
          {"TYPENAME"=>
            {"names"=>["pg_catalog", "int4"],
             "typemod"=>-1,
             "location"=>46}},
         "mode"=>116}}],
    "returnType"=>
     {"TYPENAME"=>
       {"names"=>["pg_catalog", "int4"],
        "setof"=>true,
        "typemod"=>-1,
        "location"=>36}},
    "options"=>
     [{"DEFELEM"=>
        {"defname"=>"as",
         "arg"=>["\n    SELECT * FROM foo WHERE fooid = $1;\n"],
         "defaction"=>0,
         "location"=>51}},
      {"DEFELEM"=>
        {"defname"=>"language",
         "arg"=>"sql",
         "defaction"=>0,
         "location"=>98}}]}}]
  end

  it 'transforms NULL values correctly' do
    query = described_class.parse("SELECT * FROM x WHERE object_id SIMILAR TO ?")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['x']
    expect(query.parsetree).to eq [{"SELECT"=>
      {"targetList"=>
        [{"RESTARGET"=>
            {"val"=>{"COLUMNREF"=>{"fields"=>[{"A_STAR"=>{}}], "location"=>7}},
             "location"=>7}}],
       "fromClause"=>
        [{"RANGEVAR"=>
           {"relname"=>"x", "inhOpt"=>2, "relpersistence"=>"p", "location"=>14}}],
       "whereClause"=>
        {"AEXPR"=>
          {"name"=>["~"],
           "lexpr"=>{"COLUMNREF"=>{"fields"=>["object_id"], "location"=>22}},
           "rexpr"=>
            {"FUNCCALL"=>
              {"funcname"=>["pg_catalog", "similar_escape"],
               "args"=>
                [{"PARAMREF"=>{"location"=>43}},
                 {"A_CONST"=>
                   {"type"=>"null", "val"=>nil, "location"=>-1}}],
               "location"=>32}},
           "location"=>32}},
       "op"=>0}}]
  end

  # https://github.com/lfittl/pg_query/issues/47
  it 'transforms A_CONST in functions correctly (bug case)' do
    query = described_class.parse("SELECT concat(p.firstname, ' ', p.lastname) AS a")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{"SELECT"=>
      {"targetList"=>
        [{"RESTARGET"=>
          {"name"=>"a", "val"=>
            {"FUNCCALL"=>{"funcname"=>["concat"], "args"=>[
              {"COLUMNREF"=>{"fields"=>["p", "firstname"], "location"=>14}},
              {"A_CONST"=>{"type"=>"string", "val"=>" ", "location"=>27}},
              {"COLUMNREF"=>{"fields"=>["p", "lastname"], "location"=>32}}
            ],
             "location"=>7}},
           "location"=>7}}],
         "op"=>0}}]
  end

  # https://github.com/lfittl/pg_query/issues/66
  it 'transforms A_EXPR for BETWEEN statements correctly (bug case)' do
    query = described_class.parse("SELECT 2 BETWEEN 3 AND 4")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.parsetree).to eq [{ 'SELECT' =>
     { 'targetList' =>
       [{ 'RESTARGET' =>
          { 'val' =>
            { 'AEXPR' =>
              { 'name' => ['BETWEEN'],
                'lexpr' =>
                { 'A_CONST' => { 'val' => 2, 'location' => 7, 'type' => 'integer' } },
                'rexpr' =>
                [{ 'A_CONST' => { 'val' => 3, 'location' => 17, 'type' => 'integer' } },
                 { 'A_CONST' => { 'val' => 4, 'location' => 23, 'type' => 'integer' } }],
                'location' => 9 } },
            'location' => 7 } }],
       'op' => 0 } }]
  end
end
