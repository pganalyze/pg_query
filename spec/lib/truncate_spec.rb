require 'spec_helper'

describe PgQuery, '#truncate' do
  it 'omits target list' do
    query = 'SELECT a, b, c, d, e, f FROM xyz WHERE a = b'
    expect(described_class.parse(query).truncate(40)).to eq 'SELECT ... FROM xyz WHERE a = b'
  end

  it 'omits with part of CTEs' do
    query = 'WITH x AS (SELECT * FROM y) SELECT * FROM x'
    expect(described_class.parse(query).truncate(40)).to eq 'WITH x AS (...) SELECT * FROM x'
  end

  it 'omits where clause' do
    query = 'SELECT * FROM z WHERE a = b AND x = y'
    expect(described_class.parse(query).truncate(30)).to eq 'SELECT * FROM z WHERE ...'
  end

  it 'omits INSERT field list' do
    query = 'INSERT INTO "x" (a, b, c, d, e, f) VALUES (?)'
    expect(described_class.parse(query).truncate(32)).to eq 'INSERT INTO x (...) VALUES (?)'
  end

  it 'performs a simple truncation if necessary' do
    query = 'SELECT * FROM t'
    expect(described_class.parse(query).truncate(10)).to eq 'SELECT ...'
  end

  it 'works problematic cases' do
    query = 'SELECT CASE WHEN $2.typtype = ? THEN $2.typtypmod ELSE $1.atttypmod END'
    expect(described_class.parse(query).truncate(50)).to eq 'SELECT ...'
  end
end
