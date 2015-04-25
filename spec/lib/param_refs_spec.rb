require 'spec_helper'

describe PgQuery, 'param_refs' do
  subject { described_class.parse(query).param_refs }

  context 'simple query' do
    let(:query) { 'SELECT * FROM x WHERE y = ? AND z = ?' }
    it { is_expected.to eq [{"location"=>26, "length"=>1}, {"location"=>36, "length"=>1}] }
  end

  context 'queries with typecasts' do
    let(:query) { 'SELECT * FROM x WHERE y = ?::text AND z < now() - INTERVAL ?' }
    it { is_expected.to eq [{"location"=>26, "length"=>1, "typename"=>"text"},
                            {"location"=>50, "length"=>10, "typename"=>"pg_catalog.interval"}] }
  end

  context 'actual param refs' do
    let(:query) { 'SELECT * FROM a WHERE x = $1 AND y = $12 AND z = $255' }
    it { is_expected.to eq [{"location"=>26, "length"=>2},
                            {"location"=>37, "length"=>3},
                            {"location"=>49, "length"=>4}] }
  end
end
