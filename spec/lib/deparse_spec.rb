require 'spec_helper'

describe PgQuery, 'deparse' do
  subject { PgQuery.parse(query).deparse }

  context 'basic SELECT statements' do
    let(:query) { 'SELECT a AS b FROM x WHERE y = 5 AND z = y' }
    it { is_expected.to eq query }
  end

  context 'complex SELECT statements' do
    let(:query) { "SELECT memory_total_bytes, memory_swap_total_bytes - memory_swap_free_bytes AS swap, date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON snapshot_id = s.id WHERE s.database_id = $0 AND s.collected_at >= $0 AND s.collected_at <= $0 ORDER BY collected_at ASC" }
    it { is_expected.to eq query }
  end

  context 'basic INSERT statements' do
    let(:query) { "INSERT INTO x (y, z) VALUES (1, 'abc')" }
    it { is_expected.to eq query }
  end

  context 'basic UPDATE statements' do
    let(:query) { "UPDATE x SET y = 1 WHERE z = 'abc'" }
    it { is_expected.to eq query }
  end
end
