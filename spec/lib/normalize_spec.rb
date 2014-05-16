require 'spec_helper'

describe PgQuery, "normalization" do
  it "should normalize a simple query" do
    q = PgQuery.normalize("SELECT 1")
    expect(q).to eq "SELECT ?"
  end
  
  it "should normalize IN(...)" do
    q = PgQuery.normalize("SELECT 1 FROM x WHERE y = 12561 AND z = '124' AND b IN (1, 2, 3)")
    expect(q).to eq "SELECT ? FROM x WHERE y = ? AND z = ? AND b IN (?, ?, ?)"
  end
  
  it "should normalize subselects" do
    q = PgQuery.normalize("SELECT 1 FROM x WHERE y = (SELECT 123 FROM a WHERE z = 'bla')")
    expect(q).to eq "SELECT ? FROM x WHERE y = (SELECT ? FROM a WHERE z = ?)"
  end
  
  it "should normalize ANY(array[...])" do
  end
  
  it "should normalize ANY(query, query)" do
  end
  
  it "should normalize SETs" do
    pending
  end
  
  it "should normalize weird SETs" do
    pending
    # SET CLIENT_ENCODING = UTF8
  end
  
  it "should not fail if it does not understand parts of the statement" do
    q = PgQuery.normalize("DEALLOCATE bla; SELECT 1")
    expect(q).to eq "DEALLOCATE bla; SELECT ?"
  end
  
  it "should not normalize pseudo-keywords" do
    pending
    q = PgQuery.normalize("SELECT extract(hour from NOW())")
    expect(q).to eq "SELECT extract(hour from NOW())"
  end
end