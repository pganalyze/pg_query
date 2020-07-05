require 'spec_helper'

describe PgQuery, '#normalize' do
  it "normalizes a simple query" do
    q = described_class.normalize("SELECT 1")
    expect(q).to eq "SELECT $1"
  end

  it "normalizes IN(...)" do
    q = described_class.normalize("SELECT 1 FROM x WHERE y = 12561 AND z = '124' AND b IN (1, 2, 3)")
    expect(q).to eq "SELECT $1 FROM x WHERE y = $2 AND z = $3 AND b IN ($4, $5, $6)"
  end

  it "normalizes subselects" do
    q = described_class.normalize("SELECT 1 FROM x WHERE y = (SELECT 123 FROM a WHERE z = 'bla')")
    expect(q).to eq "SELECT $1 FROM x WHERE y = (SELECT $2 FROM a WHERE z = $3)"
  end

  it "normalizes ANY(array[...])" do
    q = described_class.normalize("SELECT * FROM x WHERE y = ANY(array[1, 2])")
    expect(q).to eq "SELECT * FROM x WHERE y = ANY(array[$1, $2])"
  end

  it "normalizes ANY(query)" do
    q = described_class.normalize("SELECT * FROM x WHERE y = ANY(SELECT 1)")
    expect(q).to eq "SELECT * FROM x WHERE y = ANY(SELECT $1)"
  end

  it "works with complicated strings" do
    q = described_class.normalize("SELECT U&'d\\0061t\\+000061' FROM x")
    expect(q).to eq "SELECT $1 FROM x"

    q = described_class.normalize("SELECT u&'d\\0061t\\+000061'    FROM x")
    expect(q).to eq "SELECT $1    FROM x"

    q = described_class.normalize("SELECT * FROM x WHERE z NOT LIKE E'abc'AND TRUE")
    expect(q).to eq "SELECT * FROM x WHERE z NOT LIKE $1AND $2"

    q = described_class.normalize("SELECT U&'d\\0061t\\+000061'-- comment\nFROM x")
    expect(q).to eq "SELECT $1-- comment\nFROM x"
  end

  it "normalizes COPY" do
    q = described_class.normalize("COPY (SELECT * FROM t WHERE id IN ('1', '2')) TO STDOUT")
    expect(q).to eq "COPY (SELECT * FROM t WHERE id IN ($1, $2)) TO STDOUT"
  end

  it "normalizes SETs" do
    q = described_class.normalize("SET test=123")
    expect(q).to eq "SET test=$1"
  end

  it "normalizes weird SETs" do
    q = described_class.normalize("SET CLIENT_ENCODING = UTF8")
    expect(q).to eq "SET CLIENT_ENCODING = $1"
  end

  it "does not fail if it does not understand parts of the statement" do
    q = described_class.normalize("DEALLOCATE bla; SELECT 1")
    expect(q).to eq "DEALLOCATE bla; SELECT $1"
  end

  it 'normalizes EPXLAIN' do
    q = described_class.normalize('EXPLAIN SELECT x FROM y WHERE z = 1')
    expect(q).to eq 'EXPLAIN SELECT x FROM y WHERE z = $1'
  end

  it 'normalizes DECLARE CURSOR' do
    q = described_class.normalize('DECLARE cursor_b CURSOR FOR SELECT * FROM databases WHERE id = 23')
    expect(q).to eq 'DECLARE cursor_b CURSOR FOR SELECT * FROM databases WHERE id = $1'
  end
end
