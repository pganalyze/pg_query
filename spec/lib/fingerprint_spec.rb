require 'spec_helper'

def fingerprint(qstr)
  q = PgQuery.parse(qstr)
  q.fingerprint
end

describe PgQuery, "fingerprint" do
  it "should work for basic cases" do
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

  it "should work for multi-statement queries" do
    expect(fingerprint("SET x=?; SELECT A")).to eq fingerprint("SET x=?; SELECT a")
    expect(fingerprint("SET x=?; SELECT A")).not_to eq fingerprint("SELECT a")
  end

  it "should ignore aliases" do
    expect(fingerprint("SELECT a AS b")).to eq fingerprint("SELECT a AS c")
    expect(fingerprint("SELECT a")).to eq fingerprint("SELECT a AS c")
    expect(fingerprint("SELECT * FROM a AS b")).to eq fingerprint("SELECT * FROM a AS c")
    expect(fingerprint("SELECT * FROM a")).to eq fingerprint("SELECT * FROM a AS c")
    expect(fingerprint("SELECT * FROM (SELECT * FROM x AS y) AS a")).to eq fingerprint("SELECT * FROM (SELECT * FROM x AS z) AS b")
    expect(fingerprint("SELECT a AS b UNION SELECT x AS y")).to eq fingerprint("SELECT a AS c UNION SELECT x AS z")
  end

  it "should ignore aliases referenced in query" do
    pending
    expect(fingerprint("SELECT s1.id FROM snapshots s1")).to eq fingerprint("SELECT s2.id FROM snapshots s2")
    expect(fingerprint("SELECT a AS b ORDER BY b")).to eq fingerprint("SELECT a AS c ORDER BY c")
  end

  it "should ignore param references" do
    expect(fingerprint("SELECT $1")).to eq fingerprint("SELECT $2")
  end

  it "should ignore SELECT target list ordering" do
    expect(fingerprint("SELECT a, b FROM x")).to eq fingerprint("SELECT b, a FROM x")
    expect(fingerprint("SELECT ?, b FROM x")).to eq fingerprint("SELECT b, ? FROM x")
    expect(fingerprint("SELECT ?, ?, b FROM x")).to eq fingerprint("SELECT ?, b, ? FROM x")

    # Test uniqueness
    expect(fingerprint("SELECT a, c FROM x")).not_to eq fingerprint("SELECT b, a FROM x")
    expect(fingerprint("SELECT b FROM x")).not_to eq fingerprint("SELECT b, a FROM x")
  end

  it "should ignore INSERT cols ordering" do
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
