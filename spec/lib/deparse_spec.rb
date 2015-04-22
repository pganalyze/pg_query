require 'spec_helper'

describe PgQuery, 'deparse' do
  it 'can deparse basic SELECT statements' do
    query = PgQuery.parse('SELECT a AS b FROM x WHERE y = 5 AND z = y')
    expect(query.deparse).to eq 'SELECT a AS b FROM x WHERE y = 5 AND z = y'
  end

  it 'can deparse basic INSERT statements' do
    query = PgQuery.parse("INSERT INTO x (y, z) VALUES (1, 'abc')")
    expect(query.deparse).to eq "INSERT INTO x (y, z) VALUES (1, 'abc')"
  end

  it 'can deparse basic UPDATE statements' do
    query = PgQuery.parse("UPDATE x SET y = 1 WHERE z = 'abc'")
    expect(query.deparse).to eq "UPDATE x SET y = 1 WHERE z = 'abc'"
  end
end
