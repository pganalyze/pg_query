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
end
