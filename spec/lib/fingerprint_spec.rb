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

# Expected values match the upstream libpg_query fingerprint option tests
# (test/fingerprint_opts_tests.c)
FINGERPRINT_OPTS_TESTS = [
  # By default, 2+ consecutive digits in the relation name are ignored (these two match)
  ['SELECT * FROM orders_2024_01', PgQuery::FINGERPRINT_DEFAULT, '0e612f391ad711b8'],
  ['SELECT * FROM orders_2024_02', PgQuery::FINGERPRINT_DEFAULT, '0e612f391ad711b8'],
  # With FINGERPRINT_FULL_RELNAME the full relation name is fingerprinted (these two differ)
  ['SELECT * FROM orders_2024_01', PgQuery::FINGERPRINT_FULL_RELNAME, '3cc2d1ca3f22c9bf'],
  ['SELECT * FROM orders_2024_02', PgQuery::FINGERPRINT_FULL_RELNAME, '291f96ac98cf4c38'],
  # By default (Postgres 18+ behavior), the alias replaces the relation name, and the schema name is ignored
  ['SELECT * FROM sales', PgQuery::FINGERPRINT_DEFAULT, '4d93c901b91cb364'],
  ['SELECT * FROM public.sales', PgQuery::FINGERPRINT_DEFAULT, '4d93c901b91cb364'],
  ['SELECT * FROM sales s', PgQuery::FINGERPRINT_DEFAULT, '93a3bbe18171c380'],
  # With FINGERPRINT_RANGEVAR_IGNORE_ALIASES, aliases are ignored (matches "SELECT * FROM sales" above)
  ['SELECT * FROM sales s', PgQuery::FINGERPRINT_RANGEVAR_IGNORE_ALIASES, '4d93c901b91cb364'],
  # With FINGERPRINT_RANGEVAR_INCLUDE_SCHEMA, the schema name is fingerprinted (differs from "SELECT * FROM sales" above)
  ['SELECT * FROM public.sales', PgQuery::FINGERPRINT_RANGEVAR_INCLUDE_SCHEMA, '78d676e53f612747'],
  # ... whilst aliases still replace the relation name
  ['SELECT * FROM public.sales s', PgQuery::FINGERPRINT_RANGEVAR_INCLUDE_SCHEMA, '9cf22829ca3b350b'],
  # FINGERPRINT_RANGEVAR_PG17_COMPAT matches the fingerprint from libpg_query 17
  ['SELECT * FROM x AS a, y AS b', PgQuery::FINGERPRINT_RANGEVAR_PG17_COMPAT, '4e9acae841dae228'],
  # All flags combined
  ['SELECT * FROM public.orders_2024_01 o', PgQuery::FINGERPRINT_RANGEVAR_PG17_COMPAT | PgQuery::FINGERPRINT_FULL_RELNAME, '115077f8a9c3c10d']
].freeze

ALL_FINGERPRINT_OPTS = [
  PgQuery::FINGERPRINT_DEFAULT,
  PgQuery::FINGERPRINT_RANGEVAR_IGNORE_ALIASES,
  PgQuery::FINGERPRINT_RANGEVAR_INCLUDE_SCHEMA,
  PgQuery::FINGERPRINT_RANGEVAR_PG17_COMPAT,
  PgQuery::FINGERPRINT_FULL_RELNAME,
  PgQuery::FINGERPRINT_RANGEVAR_PG17_COMPAT | PgQuery::FINGERPRINT_FULL_RELNAME
].freeze

describe PgQuery, "#fingerprint" do
  fingerprint_defs.each do |testdef|
    it format("returns expected hash parts for '%s'", testdef['input']) do
      expect(fingerprint_parts(testdef['input'])).to eq(testdef['expectedParts'])
    end

    it format("returns expected hash value for '%s'", testdef['input']) do
      expect(fingerprint(testdef['input'])).to eq(testdef['expectedHash'])
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
    expect(fingerprint("SET x=$1; SELECT A")).to eq fingerprint("SET x=$1; SELECT a")
    expect(fingerprint("SET x=$1; SELECT A")).not_to eq fingerprint("SELECT a")
  end

  it "ignores column and subquery aliases" do
    expect(fingerprint("SELECT a AS b")).to eq fingerprint("SELECT a AS c")
    expect(fingerprint("SELECT a")).to eq fingerprint("SELECT a AS c")
    expect(fingerprint("SELECT * FROM (SELECT * FROM x AS y) AS a")).to eq fingerprint("SELECT * FROM (SELECT * FROM x AS y) AS b")
    expect(fingerprint("SELECT a AS b UNION SELECT x AS y")).to eq fingerprint("SELECT a AS c UNION SELECT x AS z")
  end

  it "fingerprints relation aliases instead of relation names (like Postgres 18+ query IDs)" do
    expect(fingerprint("SELECT * FROM a AS b")).not_to eq fingerprint("SELECT * FROM a AS c")
    expect(fingerprint("SELECT * FROM a")).not_to eq fingerprint("SELECT * FROM a AS c")
    expect(fingerprint("SELECT * FROM a AS c")).to eq fingerprint("SELECT * FROM b AS c")
    expect(fingerprint("SELECT * FROM a")).to eq fingerprint("SELECT * FROM s.a")
  end

  it "ignores param references" do
    expect(fingerprint("SELECT $1")).to eq fingerprint("SELECT $2")
  end

  it "ignores SELECT target list ordering" do
    expect(fingerprint("SELECT a, b FROM x")).to eq fingerprint("SELECT b, a FROM x")
    expect(fingerprint("SELECT $1, b FROM x")).to eq fingerprint("SELECT b, $1 FROM x")
    expect(fingerprint("SELECT $1, $2, b FROM x")).to eq fingerprint("SELECT $1, b, $2 FROM x")

    # Test uniqueness
    expect(fingerprint("SELECT a, c FROM x")).not_to eq fingerprint("SELECT b, a FROM x")
    expect(fingerprint("SELECT b FROM x")).not_to eq fingerprint("SELECT b, a FROM x")
  end

  it "ignores INSERT cols ordering" do
    expect(fingerprint("INSERT INTO test (a, b) VALUES ($1, $2)")).to eq fingerprint("INSERT INTO test (b, a) VALUES ($1, $2)")

    # Test uniqueness
    expect(fingerprint("INSERT INTO test (a, c) VALUES ($1, $2)")).not_to eq fingerprint("INSERT INTO test (b, a) VALUES ($1, $2)")
    expect(fingerprint("INSERT INTO test (b) VALUES ($1, $2)")).not_to eq fingerprint("INSERT INTO test (b, a) VALUES ($1, $2)")
  end

  it 'ignores IN list size (simple)' do
    q1 = 'SELECT * FROM x WHERE y IN ($1, $2, $3)'
    q2 = 'SELECT * FROM x WHERE y IN ($1)'
    expect(fingerprint(q1)).to eq fingerprint(q2)
  end

  it 'ignores IN list size (complex)' do
    q1 = 'SELECT * FROM x WHERE y IN ( $1::uuid, $2::uuid, $3::uuid )'
    q2 = 'SELECT * FROM x WHERE y IN ( $1::uuid )'
    expect(fingerprint(q1)).to eq fingerprint(q2)
  end

  context "with the C implementation (PgQuery.fingerprint)" do
    it "returns the same fingerprint as the Ruby implementation" do
      expect(PgQuery.fingerprint("SELECT * FROM x WHERE y = $1")).to eq fingerprint("SELECT * FROM x WHERE y = $1")
    end

    it "raises an error for invalid queries" do
      expect { PgQuery.fingerprint("SELECT FROM WHERE") }.to raise_error(PgQuery::ParseError)
    end

    FINGERPRINT_OPTS_TESTS.each do |input, opts, expected|
      it format("returns expected hash value for '%s' with options %d", input, opts) do
        expect(PgQuery.fingerprint(input, opts: opts)).to eq expected
      end
    end
  end

  context "with fingerprint options" do
    FINGERPRINT_OPTS_TESTS.each do |input, opts, expected|
      it format("returns expected hash value for '%s' with options %d", input, opts) do
        expect(PgQuery.parse(input).fingerprint(opts: opts)).to eq expected
      end
    end

    it "uses the Postgres 18+ defaults when no options are passed" do
      expect(PgQuery.parse("SELECT * FROM sales s").fingerprint).to eq PgQuery.parse("SELECT * FROM sales s").fingerprint(opts: PgQuery::FINGERPRINT_DEFAULT)
    end

    # Ensures the Ruby implementation matches the C implementation for all option combinations
    fingerprint_defs.each do |testdef|
      ALL_FINGERPRINT_OPTS.each do |opts|
        it format("matches the C implementation for '%s' with options %d", testdef['input'], opts) do
          expect(PgQuery.parse(testdef['input']).fingerprint(opts: opts)).to eq PgQuery.fingerprint(testdef['input'], opts: opts)
        end
      end
    end
  end
end
