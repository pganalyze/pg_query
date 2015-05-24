require 'spec_helper'

describe PgQuery do
  def parse_expr(expr)
    q = described_class.parse("SELECT " + expr + " FROM x")
    expect(q.parsetree).not_to be_nil
    r = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(r["AEXPR"]).not_to be_nil
    r["AEXPR"]
  end

  it "parses a normalized query" do
    query = described_class.parse("SELECT ? FROM x")
    expect(query.parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil,
                                    "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"PARAMREF"=>{"number"=>0, "location"=>7}}, "location"=>7}}],
                                    "fromClause"=>[{"RANGEVAR"=>{"schemaname"=>nil, "relname"=>"x", "inhOpt"=>2, "relpersistence"=>"p", "alias"=>nil, "location"=>14}}],
                                    "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>false, "larg"=>nil, "rarg"=>nil}}]
    expect(query.query).to eq "SELECT ? FROM x"
  end

  it 'keep locations correct' do
    query = described_class.parse("SELECT ?, 123")
    targetlist = query.parsetree[0]["SELECT"]["targetList"]
    expect(targetlist[0]["RESTARGET"]["location"]).to eq 7
    expect(targetlist[1]["RESTARGET"]["location"]).to eq 10
  end

  it "parses INTERVAL ?" do
    query = described_class.parse("SELECT INTERVAL ?")
    expect(query.parsetree).not_to be_nil
    targetlist = query.parsetree[0]["SELECT"]["targetList"]
    expect(targetlist[0]["RESTARGET"]["val"]).to eq("TYPECAST" => {"arg"=>{"PARAMREF" => {"number"=>0, "location"=>16}},
                                                    "typeName"=>{"TYPENAME"=>{"names"=>["pg_catalog", "interval"], "typeOid"=>0,
                                                                 "setof"=>false, "pct_type"=>false, "typmods"=>nil,
                                                                 "typemod"=>-1, "arrayBounds"=>nil, "location"=>7}},
                                                    "location"=>-1})
  end

  it "parses INTERVAL ? hour" do
    q = described_class.parse("SELECT INTERVAL ? hour")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("TYPECAST" => {"arg"=>{"PARAMREF" => {"number"=>0, "location"=>16}},
                                      "typeName"=>{"TYPENAME"=>{"names"=>["pg_catalog", "interval"], "typeOid"=>0,
                                                                "setof"=>false, "pct_type"=>false,
                                                                "typmods"=>[{"A_CONST"=>{"val"=>0, "location"=>-1}}],
                                                                "typemod"=>-1, "arrayBounds"=>nil, "location"=>7}},
                                       "location"=>-1})
  end

  it "parses INTERVAL (?) ?" do
    query = described_class.parse("SELECT INTERVAL (?) ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses 'a ? b' in target list" do
    q = described_class.parse("SELECT a ? b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>7}},
                                                  "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>11}},
                                    "location"=>9})
  end

  it "fails on '? 10' in target list" do
    # IMPORTANT: This is a difference of our patched parser from the main PostgreSQL parser
    #
    # This should be parsed as a left-unary operator, but we can't
    # support that due to keyword/function duality (e.g. JOIN)
    expect { described_class.parse("SELECT ? 10") }.to raise_error do |error|
      expect(error).to be_a(described_class::ParseError)
      expect(error.message).to eq "syntax error at or near \"10\""
    end
  end

  it "mis-parses on '? a' in target list" do
    # IMPORTANT: This is a difference of our patched parser from the main PostgreSQL parser
    #
    # This is mis-parsed as a target list name (should be a column reference),
    # but we can't avoid that.
    q = described_class.parse("SELECT ? a")
    expect(q.parsetree).not_to be_nil
    restarget = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]
    expect(restarget).to eq("name"=>"a", "indirection"=>nil,
                            "val"=>{"PARAMREF"=>{"number"=>0, "location"=>7}},
                            "location"=>7)
  end

  it "parses 'a ?, b' in target list" do
    q = described_class.parse("SELECT a ?, b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>7}},
                                                  "rexpr"=>nil,
                                   "location"=>9})
  end

  it "parses 'a ? AND b' in where clause" do
    q = described_class.parse("SELECT * FROM x WHERE a ? AND b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["whereClause"]
    expect(expr).to eq("AEXPR AND"=>{"lexpr"=>{"AEXPR"=>{"name"=>["?"],
                                               "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>22}},
                                               "rexpr"=>nil, "location"=>24}},
                                     "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>30}},
                                     "location"=>26})
  end

  it "parses 'JOIN y ON a = ? JOIN z ON c = d'" do
    # JOIN can be both a keyword and a function, this test is to make sure we treat it as a keyword in this case
    q = described_class.parse("SELECT * FROM x JOIN y ON a = ? JOIN z ON c = d")
    expect(q.parsetree).not_to be_nil
  end

  it "parses 'a ? b' in where clause" do
    q = described_class.parse("SELECT * FROM x WHERE a ? b")
    expect(q.parsetree).not_to be_nil
    expr = q.parsetree[0]["SELECT"]["whereClause"]
    expect(expr).to eq("AEXPR" => {"name"=>["?"], "lexpr"=>{"COLUMNREF"=>{"fields"=>["a"], "location"=>22}},
                                                  "rexpr"=>{"COLUMNREF"=>{"fields"=>["b"], "location"=>26}},
                                   "location"=>24})
  end

  it "parses BETWEEN ? AND ?" do
    query = described_class.parse("SELECT x WHERE y BETWEEN ? AND ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses ?=?" do
    e = parse_expr("?=?")
    expect(e["name"]).to eq ["="]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?=x" do
    e = parse_expr("?=x")
    expect(e["name"]).to eq ["="]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["COLUMNREF"]).not_to be_nil
  end

  it "parses x=?" do
    e = parse_expr("x=?")
    expect(e["name"]).to eq ["="]
    expect(e["lexpr"]["COLUMNREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?!=?" do
    e = parse_expr("?!=?")
    expect(e["name"]).to eq ["<>"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?!=x" do
    e = parse_expr("?!=x")
    expect(e["name"]).to eq ["<>"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["COLUMNREF"]).not_to be_nil
  end

  it "parses x!=?" do
    e = parse_expr("x!=?")
    expect(e["name"]).to eq ["<>"]
    expect(e["lexpr"]["COLUMNREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?-?" do
    e = parse_expr("?-?")
    expect(e["name"]).to eq ["-"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?<?-?" do
    e = parse_expr("?<?-?")
    expect(e["name"]).to eq ["<"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["AEXPR"]).not_to be_nil
  end

  it "parses ?+?" do
    e = parse_expr("?+?")
    expect(e["name"]).to eq ["+"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?*?" do
    e = parse_expr("?*?")
    expect(e["name"]).to eq ["*"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  it "parses ?/?" do
    e = parse_expr("?/?")
    expect(e["name"]).to eq ["/"]
    expect(e["lexpr"]["PARAMREF"]).not_to be_nil
    expect(e["rexpr"]["PARAMREF"]).not_to be_nil
  end

  # http://www.postgresql.org/docs/devel/static/functions-json.html
  # http://www.postgresql.org/docs/devel/static/hstore.html
  it "parses hstore/JSON operators containing ?" do
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
  it "parses geometric operators containing ?" do
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

  it "parses substituted pseudo keywords in extract()" do
    q = described_class.parse("SELECT extract(? from NOW())")
    expr = q.parsetree[0]["SELECT"]["targetList"][0]["RESTARGET"]["val"]
    expect(expr).to eq("FUNCCALL" => {"funcname"=>["pg_catalog", "date_part"],
                                      "args"=>[{"PARAMREF"=>{"number"=>0, "location"=>15}},
                                               {"FUNCCALL"=>{"funcname"=>["now"], "args"=>nil, "agg_order"=>nil,
                                                             "agg_filter"=>nil, "agg_within_group"=>false,
                                                             "agg_star"=>false, "agg_distinct"=>false,
                                                             "func_variadic"=>false, "over"=>nil, "location"=>22}}],
                                      "agg_order"=>nil, "agg_filter"=>nil, "agg_within_group"=>false,
                                      "agg_star"=>false, "agg_distinct"=>false,
                                      "func_variadic"=>false, "over"=>nil, "location"=>7})
  end

  it "parses $1?" do
    query = described_class.parse("SELECT 1 FROM x WHERE x IN ($1?, $1?)")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET x = ?" do
    query = described_class.parse("SET statement_timeout = ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET x=?" do
    query = described_class.parse("SET statement_timeout=?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET TIME ZONE ?" do
    query = described_class.parse("SET TIME ZONE ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET SCHEMA ?" do
    query = described_class.parse("SET SCHEMA ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET ROLE ?" do
    query = described_class.parse("SET ROLE ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET SESSION AUTHORIZATION ?" do
    query = described_class.parse("SET SESSION AUTHORIZATION ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses SET encoding = UTF?" do
    query = described_class.parse("SET encoding = UTF?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses ?=ANY(..) constructs" do
    query = described_class.parse("SELECT 1 FROM x WHERE ?= ANY(z)")
    expect(query.parsetree).not_to be_nil
  end

  it "parses KEYWORD? constructs" do
    query = described_class.parse("select * from sessions where pid ilike? and id=? ")
    expect(query.parsetree).not_to be_nil
  end

  it "parses E?KEYWORD constructs" do
    query = described_class.parse("SELECT 1 FROM x WHERE nspname NOT LIKE E?AND nspname NOT LIKE ?")
    expect(query.parsetree).not_to be_nil
  end

  it "parses complicated queries" do
    query = described_class.parse("BEGIN;SET statement_timeout=?;COMMIT;SELECT DISTINCT ON (nspname, seqname) nspname, seqname, quote_ident(nspname) || ? || quote_ident(seqname) AS safename, typname FROM ( SELECT depnsp.nspname, dep.relname as seqname, typname FROM pg_depend JOIN pg_class on classid = pg_class.oid JOIN pg_class dep on dep.oid = objid JOIN pg_namespace depnsp on depnsp.oid= dep.relnamespace JOIN pg_class refclass on refclass.oid = refclassid JOIN pg_class ref on ref.oid = refobjid JOIN pg_namespace refnsp on refnsp.oid = ref.relnamespace JOIN pg_attribute refattr ON (refobjid, refobjsubid) = (refattr.attrelid, refattr.attnum) JOIN pg_type ON refattr.atttypid = pg_type.oid WHERE pg_class.relname = ? AND refclass.relname = ? AND dep.relkind in (?) AND ref.relkind in (?) AND typname IN (?) UNION ALL SELECT nspname, seq.relname, typname FROM pg_attrdef JOIN pg_attribute ON (attrelid, attnum) = (adrelid, adnum) JOIN pg_type on pg_type.oid = atttypid JOIN pg_class rel ON rel.oid = attrelid JOIN pg_class seq ON seq.relname = regexp_replace(adsrc, $re$^nextval\\(?::regclass\\)$$re$, $$\\?$$) AND seq.relnamespace = rel.relnamespace JOIN pg_namespace nsp ON nsp.oid = seq.relnamespace WHERE adsrc ~ ? AND seq.relkind = ? AND typname IN (?) UNION ALL SELECT nspname, relname, CAST(? AS TEXT) FROM pg_class JOIN pg_namespace nsp ON nsp.oid = relnamespace WHERE relkind = ? ) AS seqs ORDER BY nspname, seqname, typname")
    expect(query.parsetree).not_to be_nil
  end

  it "parses cast(? as varchar(?))" do
    query = described_class.parse("SELECT cast(? as varchar(?))")
    expect(query.parsetree).not_to be_nil
  end
end
