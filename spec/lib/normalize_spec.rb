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
  
  it "should work with complicated strings" do
    q = PgQuery.normalize("SELECT U&'d\\0061t\\+000061' FROM x")
    expect(q).to eq "SELECT ? FROM x"
    
    q = PgQuery.normalize("SELECT u&'d\\0061t\\+000061'    FROM x")
    expect(q).to eq "SELECT ?    FROM x"
    
    q = PgQuery.normalize("SELECT * FROM x WHERE z NOT LIKE E'abc'AND TRUE")
    expect(q).to eq "SELECT * FROM x WHERE z NOT LIKE ?AND ?"
    
    # We can't avoid this easily, so treat it as known behaviour that we remove comments in this case
    q = PgQuery.normalize("SELECT U&'d\\0061t\\+000061'-- comment\nFROM x")
    expect(q).to eq "SELECT ?\nFROM x"
  end
      
  it "should normalize SETs" do
    q = PgQuery.normalize("SET test=123")
    expect(q).to eq "SET test=?"
  end
  
  it "should normalize weird SETs" do
    q = PgQuery.normalize("SET CLIENT_ENCODING = UTF8")
    expect(q).to eq "SET CLIENT_ENCODING = ?"
  end
  
  it "should not fail if it does not understand parts of the statement" do
    q = PgQuery.normalize("DEALLOCATE bla; SELECT 1")
    expect(q).to eq "DEALLOCATE bla; SELECT ?"
  end
end