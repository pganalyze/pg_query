require 'spec_helper'

describe PgQueryparser do
  it "should parse a simple query" do
    parsetree = PgQueryparser.parse("SELECT 1")
    expect(parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}}, "location"=>7}}], "fromClause"=>nil, "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>"false", "larg"=>nil, "rarg"=>nil}}]
  end
  
  it "should handle errors" do
    expect { PgQueryparser.parse("SELECT 'ERR") }.to raise_error {|error|
      expect(error).to be_a(PgQueryparser::ParseError)
      expect(error.message).to eq "unterminated quoted string at or near \"'ERR\""
      expect(error.location).to eq 8 # 8th character in query string
    }
  end
  
  it "should parse real queries" do
    parsetree = PgQueryparser.parse("SELECT memory_total_bytes, memory_free_bytes, memory_pagecache_bytes, memory_buffers_bytes, memory_applications_bytes, (memory_swap_total_bytes - memory_swap_free_bytes) AS swap, date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON (snapshot_id = s.id) WHERE s.database_id = $0 AND s.collected_at BETWEEN $0 AND $0 ORDER BY collected_at")
    expect(parsetree).not_to be_nil
  end
end