require 'spec_helper'

describe PgQuery, '#normalize' do
  it "normalizes a simple query" do
    q = described_class.normalize("SELECT 1")
    expect(q).to eq "SELECT ?"
  end

  it "normalizes IN(...)" do
    q = described_class.normalize("SELECT 1 FROM x WHERE y = 12561 AND z = '124' AND b IN (1, 2, 3)")
    expect(q).to eq "SELECT ? FROM x WHERE y = ? AND z = ? AND b IN (?, ?, ?)"
  end

  it "normalizes subselects" do
    q = described_class.normalize("SELECT 1 FROM x WHERE y = (SELECT 123 FROM a WHERE z = 'bla')")
    expect(q).to eq "SELECT ? FROM x WHERE y = (SELECT ? FROM a WHERE z = ?)"
  end

  it "normalizes ANY(array[...])" do
    q = described_class.normalize("SELECT * FROM x WHERE y = ANY(array[1, 2])")
    expect(q).to eq "SELECT * FROM x WHERE y = ANY(array[?, ?])"
  end

  it "normalizes ANY(query)" do
    q = described_class.normalize("SELECT * FROM x WHERE y = ANY(SELECT 1)")
    expect(q).to eq "SELECT * FROM x WHERE y = ANY(SELECT ?)"
  end

  it "works with complicated strings" do
    q = described_class.normalize("SELECT U&'d\\0061t\\+000061' FROM x")
    expect(q).to eq "SELECT ? FROM x"

    q = described_class.normalize("SELECT u&'d\\0061t\\+000061'    FROM x")
    expect(q).to eq "SELECT ?    FROM x"

    q = described_class.normalize("SELECT * FROM x WHERE z NOT LIKE E'abc'AND TRUE")
    expect(q).to eq "SELECT * FROM x WHERE z NOT LIKE ?AND ?"

    # We can't avoid this easily, so treat it as known behaviour that we remove comments in this case
    q = described_class.normalize("SELECT U&'d\\0061t\\+000061'-- comment\nFROM x")
    expect(q).to eq "SELECT ?\nFROM x"
  end

  it "normalizes COPY" do
    q = described_class.normalize("COPY (SELECT * FROM t WHERE id IN ('1', '2')) TO STDOUT")
    expect(q).to eq "COPY (SELECT * FROM t WHERE id IN (?, ?)) TO STDOUT"
  end

  it "normalizes SETs" do
    q = described_class.normalize("SET test=123")
    expect(q).to eq "SET test=?"
  end

  it "normalizes weird SETs" do
    q = described_class.normalize("SET CLIENT_ENCODING = UTF8")
    expect(q).to eq "SET CLIENT_ENCODING = ?"
  end

  it "does not fail if it does not understand parts of the statement" do
    q = described_class.normalize("DEALLOCATE bla; SELECT 1")
    expect(q).to eq "DEALLOCATE bla; SELECT ?"
  end

  it 'normalizes EPXLAIN' do
    q = described_class.normalize('EXPLAIN SELECT x FROM y WHERE z = 1')
    expect(q).to eq 'EXPLAIN SELECT x FROM y WHERE z = ?'
  end
end
