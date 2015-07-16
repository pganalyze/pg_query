require 'spec_helper'

describe PgQuery, '#truncate' do
  it 'omits target list first' do
    query = 'SELECT a, b, c, d, e, f FROM xyz WHERE a = b'
    expect(PgQuery.parse(query).truncate(40)).to eq 'SELECT ... FROM xyz WHERE a = b'
  end

  it 'performs a simple truncation if necessary' do
    query = 'SELECT * FROM t'
    expect(PgQuery.parse(query).truncate(10)).to eq 'SELECT ...'
  end
end
