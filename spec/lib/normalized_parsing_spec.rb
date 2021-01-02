require 'spec_helper'

describe PgQuery do
  def parse_expr(expr)
    q = described_class.parse("SELECT " + expr + " FROM x")
    expect(q.tree).not_to be_nil
    r = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(r[described_class::A_EXPR]).not_to be_nil
    r[described_class::A_EXPR]
  end

  it "parses a normalized query" do
    query = described_class.parse("SELECT ? FROM x")
    expect(query.tree).to eq [{described_class::RAW_STMT=>{described_class::STMT_FIELD=>{described_class::SELECT_STMT=>{described_class::TARGET_LIST_FIELD=>[{described_class::RES_TARGET=>{"val"=>{described_class::PARAM_REF=>{"location"=>7}}, "location"=>7}}],
                                    "fromClause"=>[{described_class::RANGE_VAR=>{"relname"=>"x", "inh"=>true, "relpersistence"=>"p", "location"=>14}}],
                                    "limitOption"=>0,
                                    "op"=>0}}}}]
    expect(query.query).to eq "SELECT ? FROM x"
  end

  it 'keep locations correct' do
    query = described_class.parse("SELECT ?, 123")
    targetlist = query.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD]
    expect(targetlist[0][described_class::RES_TARGET]["location"]).to eq 7
    expect(targetlist[1][described_class::RES_TARGET]["location"]).to eq 10
  end

  it "parses INTERVAL ?" do
    query = described_class.parse("SELECT INTERVAL ?")
    expect(query.tree).not_to be_nil
    targetlist = query.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD]
    expect(targetlist[0][described_class::RES_TARGET]["val"]).to eq(described_class::TYPE_CAST => {"arg"=>{described_class::PARAM_REF => {"location"=>16}},
                                                    "typeName"=>{described_class::TYPE_NAME=>{"names"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"interval"}}],
                                                                 "typemod"=>-1, "location"=>7}},
                                                    "location"=>-1})
  end

  it "parses INTERVAL ? hour" do
    q = described_class.parse("SELECT INTERVAL ? hour")
    expect(q.tree).not_to be_nil
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::TYPE_CAST => {"arg"=>{described_class::PARAM_REF => {"location"=>16}},
                                      "typeName"=>{described_class::TYPE_NAME=>{"names"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"interval"}}],
                                                                "typmods"=>[{described_class::A_CONST=>{"val"=>{described_class::INTEGER => {"ival" => 0}}, "location"=>-1}}],
                                                                "typemod"=>-1, "location"=>7}},
                                       "location"=>-1})
  end

  it "parses INTERVAL (?) ?" do
    query = described_class.parse("SELECT INTERVAL (?) ?")
    expect(query.tree).not_to be_nil
  end

  it "parses 'a ? b' in target list" do
    q = described_class.parse("SELECT a ? b")
    expect(q.tree).not_to be_nil
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::A_EXPR => {"kind"=>0,
                                                   "name"=>[{"String"=>{"str"=>"?"}}],
                                                   "lexpr"=>{described_class::COLUMN_REF=>{"fields"=>[{"String"=>{"str"=>"a"}}], "location"=>7}},
                                                   "rexpr"=>{described_class::COLUMN_REF=>{"fields"=>[{"String"=>{"str"=>"b"}}], "location"=>11}},
                                    "location"=>9})
  end

  it "fails on '? 10' in target list" do
    # IMPORTANT: This is a difference of our patched parser from the main PostgreSQL parser
    #
    # This should be parsed as a left-unary operator, but we can't
    # support that due to keyword/function duality (e.g. JOIN)
    expect { described_class.parse("SELECT ? 10") }.to raise_error do |error|
      expect(error).to be_a(described_class::ParseError)
      expect(error.message).to eq "syntax error at or near \"10\" (scan.l:1233)"
    end
  end

  it "mis-parses on '? a' in target list" do
    # IMPORTANT: This is a difference of our patched parser from the main PostgreSQL parser
    #
    # This is mis-parsed as a target list name (should be a column reference),
    # but we can't avoid that.
    q = described_class.parse("SELECT ? a")
    expect(q.tree).not_to be_nil
    restarget = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]
    expect(restarget).to eq("name"=>"a",
                            "val"=>{described_class::PARAM_REF=>{"location"=>7}},
                            "location"=>7)
  end

  it "parses 'a ?, b' in target list" do
    q = described_class.parse("SELECT a ?, b")
    expect(q.tree).not_to be_nil
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::A_EXPR =>
    {
      "kind"=>0,
      "name"=>[{"String"=>{"str"=>"?"}}],
      "lexpr"=>{described_class::COLUMN_REF=>{"fields"=>[{"String"=>{"str"=>"a"}}], "location"=>7}},
      "location"=>9
    })
  end

  it "parses 'a ? AND b' in where clause" do
    q = described_class.parse("SELECT * FROM x WHERE a ? AND b")
    expect(q.tree).not_to be_nil
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT]["whereClause"]
    expect(expr).to eq(described_class::BOOL_EXPR=>
    {
      "boolop"=>0,
      "args"=>[
        {
          described_class::A_EXPR=>{
            "kind"=>0,
            "name"=>[{"String"=>{"str"=>"?"}}],
            "lexpr"=>{described_class::COLUMN_REF=>{"fields"=>[{"String"=>{"str"=>"a"}}], "location"=>22}},
            "location"=>24
          }
        },
        {
          described_class::COLUMN_REF=>{
            "fields"=>[{"String"=>{"str"=>"b"}}], "location"=>30
          }
        }
      ],
      "location"=>26
    })
  end

  it "parses 'JOIN y ON a = ? JOIN z ON c = d'" do
    # JOIN can be both a keyword and a function, this test is to make sure we treat it as a keyword in this case
    q = described_class.parse("SELECT * FROM x JOIN y ON a = ? JOIN z ON c = d")
    expect(q.tree).not_to be_nil
  end

  it "parses 'a ? b' in where clause" do
    q = described_class.parse("SELECT * FROM x WHERE a ? b")
    expect(q.tree).not_to be_nil
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT]["whereClause"]
    expect(expr).to eq(described_class::A_EXPR =>
    {
      "kind"=>0,
      "name"=>[{"String"=>{"str"=>"?"}}],
      "lexpr"=>{described_class::COLUMN_REF=>{"fields"=>[{"String"=>{"str"=>"a"}}], "location"=>22}},
      "rexpr"=>{described_class::COLUMN_REF=>{"fields"=>[{"String"=>{"str"=>"b"}}], "location"=>26}},
      "location"=>24
    })
  end

  it "parses BETWEEN ? AND ?" do
    query = described_class.parse("SELECT x WHERE y BETWEEN ? AND ?")
    expect(query.tree).not_to be_nil
  end

  it "parses ?=?" do
    e = parse_expr("?=?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"="}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?=x" do
    e = parse_expr("?=x")
    expect(e["name"]).to eq [{"String"=>{"str"=>"="}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::COLUMN_REF]).not_to be_nil
  end

  it "parses x=?" do
    e = parse_expr("x=?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"="}}]
    expect(e["lexpr"][described_class::COLUMN_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?!=?" do
    e = parse_expr("?!=?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"<>"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?!=x" do
    e = parse_expr("?!=x")
    expect(e["name"]).to eq [{"String"=>{"str"=>"<>"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::COLUMN_REF]).not_to be_nil
  end

  it "parses x!=?" do
    e = parse_expr("x!=?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"<>"}}]
    expect(e["lexpr"][described_class::COLUMN_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?-?" do
    e = parse_expr("?-?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"-"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?<?-?" do
    e = parse_expr("?<?-?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"<"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::A_EXPR]).not_to be_nil
  end

  it "parses ?+?" do
    e = parse_expr("?+?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"+"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?*?" do
    e = parse_expr("?*?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"*"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses ?/?" do
    e = parse_expr("?/?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"/"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  # http://www.postgresql.org/docs/devel/static/functions-json.html
  # http://www.postgresql.org/docs/devel/static/hstore.html
  it "parses hstore/JSON operators containing ?" do
    e = parse_expr("'{\"a\":1, \"b\":2}'::jsonb ? 'b'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::A_CONST]).not_to be_nil

    e = parse_expr("? ? ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("'{\"a\":1, \"b\":2, \"c\":3}'::jsonb ?| array['b', 'c']")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?|"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::A_ARRAY_EXPR]).not_to be_nil

    e = parse_expr("? ?| ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?|"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("'[\"a\", \"b\"]'::jsonb ?& array['a', 'b']")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?&"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::A_ARRAY_EXPR]).not_to be_nil

    e = parse_expr("? ?& ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?&"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  # http://www.postgresql.org/docs/devel/static/functions-geometry.html
  it "parses geometric operators containing ?" do
    e = parse_expr("lseg '((-1,0),(1,0))' ?# box '((-2,-2),(2,2))'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?#"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("? ?# ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?#"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("?- lseg '((-1,0),(1,0))'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?-"}}]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("?- ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?-"}}]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("point '(1,0)' ?- point '(0,0)'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?-"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("? ?- ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?-"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("?| lseg '((-1,0),(1,0))'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?|"}}]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("?| ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?|"}}]
    expect(e["lexpr"]).to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("point '(0,1)' ?| point '(0,0)'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?|"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("? ?| ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?|"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("lseg '((0,0),(0,1))' ?-| lseg '((0,0),(1,0))'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?-|"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("? ?-| ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?-|"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil

    e = parse_expr("lseg '((-1,0),(1,0))' ?|| lseg '((-1,2),(1,2))'")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?||"}}]
    expect(e["lexpr"][described_class::TYPE_CAST]).not_to be_nil
    expect(e["rexpr"][described_class::TYPE_CAST]).not_to be_nil

    e = parse_expr("? ?|| ?")
    expect(e["name"]).to eq [{"String"=>{"str"=>"?||"}}]
    expect(e["lexpr"][described_class::PARAM_REF]).not_to be_nil
    expect(e["rexpr"][described_class::PARAM_REF]).not_to be_nil
  end

  it "parses substituted pseudo keywords in extract()" do
    q = described_class.parse("SELECT extract(? from NOW())")
    expr = q.tree[0][described_class::RAW_STMT][described_class::STMT_FIELD][described_class::SELECT_STMT][described_class::TARGET_LIST_FIELD][0][described_class::RES_TARGET]["val"]
    expect(expr).to eq(described_class::FUNC_CALL =>
    {
      "funcname"=>[{"String"=>{"str"=>"pg_catalog"}}, {"String"=>{"str"=>"date_part"}}],
      "args"=>[{described_class::PARAM_REF=>{"location"=>15}},
               {described_class::FUNC_CALL=>{"funcname"=>[{"String"=>{"str"=>"now"}}], "location"=>22}}],
      "location"=>7
    })
  end

  it "parses $1?" do
    query = described_class.parse("SELECT 1 FROM x WHERE x IN ($1?, $1?)")
    expect(query.tree).not_to be_nil
  end

  it "parses SET x = ?" do
    query = described_class.parse("SET statement_timeout = ?")
    expect(query.tree).not_to be_nil
  end

  it "parses SET x=?" do
    query = described_class.parse("SET statement_timeout=?")
    expect(query.tree).not_to be_nil
  end

  it "parses SET TIME ZONE ?" do
    query = described_class.parse("SET TIME ZONE ?")
    expect(query.tree).not_to be_nil
  end

  it "parses SET SCHEMA ?" do
    query = described_class.parse("SET SCHEMA ?")
    expect(query.tree).not_to be_nil
  end

  it "parses SET ROLE ?" do
    query = described_class.parse("SET ROLE ?")
    expect(query.tree).not_to be_nil
  end

  it "parses SET SESSION AUTHORIZATION ?" do
    query = described_class.parse("SET SESSION AUTHORIZATION ?")
    expect(query.tree).not_to be_nil
  end

  it "parses SET encoding = UTF?" do
    query = described_class.parse("SET encoding = UTF?")
    expect(query.tree).not_to be_nil
  end

  it "parses ?=ANY(..) constructs" do
    query = described_class.parse("SELECT 1 FROM x WHERE ?= ANY(z)")
    expect(query.tree).not_to be_nil
  end

  it "parses KEYWORD? constructs" do
    query = described_class.parse("select * from sessions where pid ilike? and id=? ")
    expect(query.tree).not_to be_nil
  end

  it "parses E?KEYWORD constructs" do
    query = described_class.parse("SELECT 1 FROM x WHERE nspname NOT LIKE E?AND nspname NOT LIKE ?")
    expect(query.tree).not_to be_nil
  end

  it "parses complicated queries" do
    query = described_class.parse("BEGIN;SET statement_timeout=?;COMMIT;SELECT DISTINCT ON (nspname, seqname) nspname, seqname, quote_ident(nspname) || ? || quote_ident(seqname) AS safename, typname FROM ( SELECT depnsp.nspname, dep.relname as seqname, typname FROM pg_depend JOIN pg_class on classid = pg_class.oid JOIN pg_class dep on dep.oid = objid JOIN pg_namespace depnsp on depnsp.oid= dep.relnamespace JOIN pg_class refclass on refclass.oid = refclassid JOIN pg_class ref on ref.oid = refobjid JOIN pg_namespace refnsp on refnsp.oid = ref.relnamespace JOIN pg_attribute refattr ON (refobjid, refobjsubid) = (refattr.attrelid, refattr.attnum) JOIN pg_type ON refattr.atttypid = pg_type.oid WHERE pg_class.relname = ? AND refclass.relname = ? AND dep.relkind in (?) AND ref.relkind in (?) AND typname IN (?) UNION ALL SELECT nspname, seq.relname, typname FROM pg_attrdef JOIN pg_attribute ON (attrelid, attnum) = (adrelid, adnum) JOIN pg_type on pg_type.oid = atttypid JOIN pg_class rel ON rel.oid = attrelid JOIN pg_class seq ON seq.relname = regexp_replace(adsrc, $re$^nextval\\(?::regclass\\)$$re$, $$\\?$$) AND seq.relnamespace = rel.relnamespace JOIN pg_namespace nsp ON nsp.oid = seq.relnamespace WHERE adsrc ~ ? AND seq.relkind = ? AND typname IN (?) UNION ALL SELECT nspname, relname, CAST(? AS TEXT) FROM pg_class JOIN pg_namespace nsp ON nsp.oid = relnamespace WHERE relkind = ? ) AS seqs ORDER BY nspname, seqname, typname")
    expect(query.tree).not_to be_nil
  end

  it "parses cast(? as varchar(?))" do
    query = described_class.parse("SELECT cast(? as varchar(?))")
    expect(query.tree).not_to be_nil
  end
end
