require 'spec_helper'
require 'json'

def fingerprint(qstr)
  q = PgQuery.parse(qstr)
  q.fingerprint
end

class FingerprintTestHash
  attr_reader :parts

  def initialize
    @parts = []
  end

  def update(part)
    @parts << part
  end
end

def fingerprint_parts(qstr)
  hash = FingerprintTestHash.new
  q = PgQuery.parse(qstr)
  q.send(:fingerprint_tree, hash)
  hash.parts
end

def fingerprint_defs
  @fingerprint_defs ||= JSON.parse File.read(File.join(__dir__, '../files/fingerprint.json'))
end

describe PgQuery, "#fingerprint" do
  fingerprint_defs.each do |testdef|
    it format("returns expected hash value for '%s'", testdef['input']) do
      expect(fingerprint(testdef['input'])).to eq(testdef['expectedHash'])
    end

    it format("returns expected hash parts for '%s'", testdef['input']) do
      expect(fingerprint_parts(testdef['input'])).to eq(testdef['expectedParts'])
    end
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
