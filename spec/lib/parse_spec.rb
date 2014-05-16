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
end

describe PgQuery, "normalized parsing" do
  it "should parse a normalized query" do
    #pending
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
  
  it "should parse ?.?" do
    pending
    query = PgQuery.parse("SELECT ?.?")
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
end