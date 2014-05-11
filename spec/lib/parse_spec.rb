require 'spec_helper'

describe PgQueryparser do
  it "should parse a simple query" do
    parsetree = PgQueryparser.parse("SELECT 1")
    expect(parsetree).to eq [{"SELECT"=>{"distinctClause"=>nil, "intoClause"=>nil, "targetList"=>[{"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"A_CONST"=>{"val"=>1, "location"=>7}}, "location"=>7}}], "fromClause"=>nil, "whereClause"=>nil, "groupClause"=>nil, "havingClause"=>nil, "windowClause"=>nil, "valuesLists"=>nil, "sortClause"=>nil, "limitOffset"=>nil, "limitCount"=>nil, "lockingClause"=>nil, "withClause"=>nil, "op"=>0, "all"=>"false", "larg"=>nil, "rarg"=>nil}}]
  end
  
  it "should handle errors" do
    expect { PgQueryparser.parse("NOT A QUERY") }.to raise_error
  end
end