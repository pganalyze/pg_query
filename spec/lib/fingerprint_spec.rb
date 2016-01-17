require 'spec_helper'

def fingerprint(qstr)
  q = PgQuery.parse(qstr)
  q.fingerprint
end

class FingerprintTestHash
  def initialize
    @parts = []
  end

  def update(part)
    @parts << part
  end

  def hexdigest
    @parts
  end
end

def fingerprint_parts(qstr)
  q = PgQuery.parse(qstr)
  q.fingerprint(hash: FingerprintTestHash.new)
end

describe PgQuery, "#fingerprint" do
  it "returns expected hash values" do
    expect(fingerprint('SELECT 1')).to eq 'f6896cf5c913b43e12713519e6dd932d5bba19ef'
    expect(fingerprint('SELECT COUNT(DISTINCT id), * FROM targets WHERE something IS NOT NULL AND elsewhere::interval < now()')).to eq '5fd30a147ad4d9851cb8a06816bfe30e8c20605c'
    expect(fingerprint('INSERT INTO test (a, b) VALUES (?, ?)')).to eq '8cd42877003c14e824ca237d5cc59c16ac3c33fa'
    expect(fingerprint('INSERT INTO test (b, a) VALUES (?, ?)')).to eq '8cd42877003c14e824ca237d5cc59c16ac3c33fa'
    expect(fingerprint('SELECT b AS x, a AS y FROM z')).to eq '836c1a419a21422f08df261eca3ecfbdd9dd1082'
    expect(fingerprint('SELECT * FROM x WHERE y IN (?)')).to eq 'aeafc881fb0bd6ff3d56a25ce30f291bf5c1ee93'
    expect(fingerprint('SELECT * FROM x WHERE y IN (?, ?, ?)')).to eq 'aeafc881fb0bd6ff3d56a25ce30f291bf5c1ee93'
    expect(fingerprint('SELECT * FROM x WHERE y IN ( ?::uuid )')).to eq 'f9751ace7942f0874d77c8d625aca65bce3c7230'
    expect(fingerprint('SELECT * FROM x WHERE y IN ( ?::uuid, ?::uuid, ?::uuid )')).to eq 'f9751ace7942f0874d77c8d625aca65bce3c7230'
  end

  it "returns expected hash parts" do
    expect(fingerprint_parts('SELECT 1')).to eq ["SelectStmt", "0", "ResTarget"]
    expect(fingerprint_parts('SELECT COUNT(DISTINCT id), * FROM targets WHERE something IS NOT NULL AND elsewhere::interval < now()')).to eq([
      "SelectStmt", "RangeVar", "2", "targets", "p", "0", "ResTarget", "ColumnRef",
      "A_Star", "ResTarget", "FuncCall", "true", "ColumnRef", "String",
      "id", "String", "count", "A_Expr", "1", "NullTest", "ColumnRef", "String",
      "something", "1", "A_Expr", "0", "TypeCast", "ColumnRef", "String", "elsewhere",
      "TypeName", "String", "pg_catalog", "String", "interval", "-1",
      "String", "<", "FuncCall", "String", "now"
    ])
    expect(fingerprint_parts('INSERT INTO test (a, b) VALUES (?, ?)')).to eq([
      "InsertStmt", "ResTarget", "a", "ResTarget", "b", "RangeVar", "2", "test", "p", "SelectStmt", "0"
    ])
    expect(fingerprint_parts('INSERT INTO test (b, a) VALUES (?, ?)')).to eq([
      "InsertStmt", "ResTarget", "a", "ResTarget", "b", "RangeVar", "2", "test", "p", "SelectStmt", "0"
    ])
    expect(fingerprint_parts('SELECT b AS x, a AS y FROM z')).to eq([
      "SelectStmt", "RangeVar", "2", "z", "p", "0", "ResTarget", "ColumnRef", "String", "a", "ResTarget", "ColumnRef", "String", "b"
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN (?)')).to eq([
      "SelectStmt", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "="
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN (?, ?, ?)')).to eq([
      "SelectStmt", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "="
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN ( ?::uuid )')).to eq([
      "SelectStmt", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "=", "TypeCast", "TypeName", "String", "uuid", "-1"
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN ( ?::uuid, ?::uuid, ?::uuid )')).to eq([
      "SelectStmt", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "=", "TypeCast", "TypeName", "String", "uuid", "-1"
    ])
  end

  it "works for basic cases" do
    expect(fingerprint("SELECT 1")).to eq fingerprint("SELECT 2")
    expect(fingerprint("SELECT  1")).to eq fingerprint("SELECT 2")
    expect(fingerprint("SELECT A")).to eq fingerprint("SELECT a")
    expect(fingerprint("SELECT \"a\"")).to eq fingerprint("SELECT a")
    expect(fingerprint("  SELECT 1;")).to eq fingerprint("SELECT 2")
    expect(fingerprint("  ")).to eq fingerprint("")
    expect(fingerprint("--comment")).to eq fingerprint("")

    # Test uniqueness
    expect(fingerprint("SELECT a")).not_to eq fingerprint("SELECT b")
    expect(fingerprint("SELECT \"A\"")).not_to eq fingerprint("SELECT a")
    expect(fingerprint("SELECT * FROM a")).not_to eq fingerprint("SELECT * FROM b")
  end

  it "works for multi-statement queries" do
    expect(fingerprint("SET x=?; SELECT A")).to eq fingerprint("SET x=?; SELECT a")
    expect(fingerprint("SET x=?; SELECT A")).not_to eq fingerprint("SELECT a")
  end

  it "ignores aliases" do
    expect(fingerprint("SELECT a AS b")).to eq fingerprint("SELECT a AS c")
    expect(fingerprint("SELECT a")).to eq fingerprint("SELECT a AS c")
    expect(fingerprint("SELECT * FROM a AS b")).to eq fingerprint("SELECT * FROM a AS c")
    expect(fingerprint("SELECT * FROM a")).to eq fingerprint("SELECT * FROM a AS c")
    expect(fingerprint("SELECT * FROM (SELECT * FROM x AS y) AS a")).to eq fingerprint("SELECT * FROM (SELECT * FROM x AS z) AS b")
    expect(fingerprint("SELECT a AS b UNION SELECT x AS y")).to eq fingerprint("SELECT a AS c UNION SELECT x AS z")
  end

  it "ignores aliases referenced in query" do
    pending
    expect(fingerprint("SELECT s1.id FROM snapshots s1")).to eq fingerprint("SELECT s2.id FROM snapshots s2")
    expect(fingerprint("SELECT a AS b ORDER BY b")).to eq fingerprint("SELECT a AS c ORDER BY c")
  end

  it "ignores param references" do
    expect(fingerprint("SELECT $1")).to eq fingerprint("SELECT $2")
  end

  it "ignores SELECT target list ordering" do
    expect(fingerprint("SELECT a, b FROM x")).to eq fingerprint("SELECT b, a FROM x")
    expect(fingerprint("SELECT ?, b FROM x")).to eq fingerprint("SELECT b, ? FROM x")
    expect(fingerprint("SELECT ?, ?, b FROM x")).to eq fingerprint("SELECT ?, b, ? FROM x")

    # Test uniqueness
    expect(fingerprint("SELECT a, c FROM x")).not_to eq fingerprint("SELECT b, a FROM x")
    expect(fingerprint("SELECT b FROM x")).not_to eq fingerprint("SELECT b, a FROM x")
  end

  it "ignores INSERT cols ordering" do
    expect(fingerprint("INSERT INTO test (a, b) VALUES (?, ?)")).to eq fingerprint("INSERT INTO test (b, a) VALUES (?, ?)")

    # Test uniqueness
    expect(fingerprint("INSERT INTO test (a, c) VALUES (?, ?)")).not_to eq fingerprint("INSERT INTO test (b, a) VALUES (?, ?)")
    expect(fingerprint("INSERT INTO test (b) VALUES (?, ?)")).not_to eq fingerprint("INSERT INTO test (b, a) VALUES (?, ?)")
  end

  it 'ignores IN list size (simple)' do
    q1 = 'SELECT * FROM x WHERE y IN (?, ?, ?)'
    q2 = 'SELECT * FROM x WHERE y IN (?)'
    expect(fingerprint(q1)).to eq fingerprint(q2)
  end

  it 'ignores IN list size (complex)' do
    q1 = 'SELECT * FROM x WHERE y IN ( ?::uuid, ?::uuid, ?::uuid )'
    q2 = 'SELECT * FROM x WHERE y IN ( ?::uuid )'
    expect(fingerprint(q1)).to eq fingerprint(q2)
  end
end
