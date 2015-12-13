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
    expect(fingerprint('SELECT 1')).to eq '31dc5500dc27777a26160cb1b0faa11495f150d8'
    expect(fingerprint('SELECT COUNT(DISTINCT id), * FROM targets WHERE something IS NOT NULL AND elsewhere::interval < now()')).to eq '1e014ccea580bb5dea8b4a66893b3c508d6261f0'
    expect(fingerprint('INSERT INTO test (a, b) VALUES (?, ?)')).to eq 'f3f2847a56d9b67f11e1905d2365bc627f852220'
    expect(fingerprint('INSERT INTO test (b, a) VALUES (?, ?)')).to eq 'f3f2847a56d9b67f11e1905d2365bc627f852220'
    expect(fingerprint('SELECT b AS x, a AS y FROM z')).to eq '7c361dd7a746418464fdf666cfae7be6a0f873aa'
    expect(fingerprint('SELECT * FROM x WHERE y IN (?)')).to eq 'd15431e54000f340c2bfca70ed3a0f31b2e55061'
    expect(fingerprint('SELECT * FROM x WHERE y IN (?, ?, ?)')).to eq 'd15431e54000f340c2bfca70ed3a0f31b2e55061'
    expect(fingerprint('SELECT * FROM x WHERE y IN ( ?::uuid )')).to eq 'bd7dcab89d5a8ad04b5f7e352030f47d5abd1eab'
    expect(fingerprint('SELECT * FROM x WHERE y IN ( ?::uuid, ?::uuid, ?::uuid )')).to eq 'bd7dcab89d5a8ad04b5f7e352030f47d5abd1eab'
  end

  it "returns expected hash parts" do
    expect(fingerprint_parts('SELECT 1')).to eq ["SelectStmt", "false", "0", "ResTarget"]
    expect(fingerprint_parts('SELECT COUNT(DISTINCT id), * FROM targets WHERE something IS NOT NULL AND elsewhere::interval < now()')).to eq([
      "SelectStmt", "false", "RangeVar", "2", "targets", "p", "0", "ResTarget", "ColumnRef",
      "A_Star", "ResTarget", "FuncCall", "true", "false", "false", "ColumnRef", "String",
      "id", "false", "String", "count", "A_Expr", "1", "NullTest", "ColumnRef", "String",
      "something", "false", "1", "A_Expr", "0", "TypeCast", "ColumnRef", "String", "elsewhere",
      "TypeName", "String", "pg_catalog", "String", "interval", "false", "false", "0", "-1",
      "String", "<", "FuncCall", "false", "false", "false", "false", "String", "now"
    ])
    expect(fingerprint_parts('INSERT INTO test (a, b) VALUES (?, ?)')).to eq([
      "InsertStmt", "ResTarget", "a", "ResTarget", "b", "RangeVar", "2", "test", "p", "SelectStmt", "false", "0"
    ])
    expect(fingerprint_parts('INSERT INTO test (b, a) VALUES (?, ?)')).to eq([
      "InsertStmt", "ResTarget", "a", "ResTarget", "b", "RangeVar", "2", "test", "p", "SelectStmt", "false", "0"
    ])
    expect(fingerprint_parts('SELECT b AS x, a AS y FROM z')).to eq([
      "SelectStmt", "false", "RangeVar", "2", "z", "p", "0", "ResTarget", "ColumnRef", "String", "a", "ResTarget", "ColumnRef", "String", "b"
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN (?)')).to eq([
      "SelectStmt", "false", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "="
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN (?, ?, ?)')).to eq([
      "SelectStmt", "false", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "="
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN ( ?::uuid )')).to eq([
      "SelectStmt", "false", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "=", "TypeCast", "TypeName", "String", "uuid", "false", "false", "0", "-1"
    ])
    expect(fingerprint_parts('SELECT * FROM x WHERE y IN ( ?::uuid, ?::uuid, ?::uuid )')).to eq([
      "SelectStmt", "false", "RangeVar", "2", "x", "p", "0", "ResTarget", "ColumnRef", "A_Star", "A_Expr", "9", "ColumnRef", "String", "y", "String", "=", "TypeCast", "TypeName", "String", "uuid", "false", "false", "0", "-1"
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
