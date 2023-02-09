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
    query = 'INSERT INTO "x" (a, b, c, d, e, f) VALUES ($1)'
    expect(described_class.parse(query).truncate(32)).to eq 'INSERT INTO x (...) VALUES (...)'
  end

  it 'omits comments' do
    query = 'SELECT $1 /* application:test */'
    expect(described_class.parse(query).truncate(100)).to eq 'SELECT $1'
  end

  it 'performs a simple truncation if necessary' do
    query = 'SELECT * FROM t'
    expect(described_class.parse(query).truncate(10)).to eq 'SELECT ...'
  end

  it 'works problematic cases' do
    query = 'SELECT CASE WHEN $2.typtype = $3 THEN $2.typtypmod ELSE $1.atttypmod END'
    expect(described_class.parse(query).truncate(50)).to eq 'SELECT ...'
  end

  it 'handles UPDATE target list' do
    query = 'UPDATE x SET a = 1, c = 2, e = \'str\''
    expect(described_class.parse(query).truncate(30)).to eq 'UPDATE x SET ... = ...'
  end

  it 'handles ON CONFLICT target list' do
    query = 'INSERT INTO y(a) VALUES(1) ON CONFLICT DO UPDATE SET a = 123456789'
    expect(described_class.parse(query).truncate(66)).to eq 'INSERT INTO y (a) VALUES (...) ON CONFLICT DO UPDATE SET ... = ...'
  end

  it 'handles complex ON CONFLICT target lists' do
    query = 'INSERT INTO foo (a, b, c, d) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29) ON CONFLICT (id) DO UPDATE SET (a, b, c, d) = (excluded.a,excluded.b,excluded.c,case when foo.d = excluded.d then excluded.d end)'
    expect(described_class.parse(query).truncate(100)).to eq 'INSERT INTO foo (a, b, c, d) VALUES (...) ON CONFLICT (id) DO UPDATE SET ... = ...'
  end

  it 'handles GRANT access privileges' do
    query = 'GRANT SELECT (abc, def, ghj) ON TABLE t1 TO r1'
    expect(described_class.parse(query).truncate(35)).to eq 'GRANT select (abc, def, ghj) ON ...'
  end
end
