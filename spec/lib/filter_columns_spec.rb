require 'spec_helper'

def filter_columns(qstr)
  q = PgQuery.parse(qstr)
  q.filter_columns
end

describe PgQuery, '#filter_columns' do
  it 'finds unqualified names' do
    expect(filter_columns('SELECT * FROM x WHERE y = ? AND z = 1')).to eq [[nil, 'y'], [nil, 'z']]
  end

  it 'finds qualified names' do
    expect(filter_columns('SELECT * FROM x WHERE x.y = ? AND x.z = 1')).to eq [['x', 'y'], ['x', 'z']]
  end

  it 'traverses into CTEs' do
    query = 'WITH a AS (SELECT * FROM x WHERE x.y = ? AND x.z = 1) SELECT * FROM a WHERE b = 5'
    expect(filter_columns(query)).to match_array [['x', 'y'], ['x', 'z'], [nil, 'b']]
  end

  it 'recognizes boolean tests' do
    expect(filter_columns('SELECT * FROM x WHERE x.y IS TRUE AND x.z IS NOT FALSE')).to eq [['x', 'y'], ['x', 'z']]
  end

  it 'finds COALESCE argument names' do
    expect(filter_columns('SELECT * FROM x WHERE x.y = COALESCE(z.a, z.b)')).to eq [['x', 'y'], ['z', 'a'], ['z', 'b']]
  end
end
