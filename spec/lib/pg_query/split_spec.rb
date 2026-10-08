require 'spec_helper'

describe PgQuery, '.split_with_parser' do
  it "splits a multi-statement string into its statements" do
    stmts = described_class.split_with_parser("SELECT 1; SELECT 2")
    expect(stmts).to eq(['SELECT 1', ' SELECT 2'])
  end

  it "returns a single statement unchanged" do
    expect(described_class.split_with_parser('SELECT 1')).to eq(['SELECT 1'])
  end

  it "does not include the trailing semicolon in a statement" do
    expect(described_class.split_with_parser('SELECT 1;')).to eq(['SELECT 1'])
  end

  it "splits on byte offsets so multibyte characters don't shift statement boundaries" do
    stmts = described_class.split_with_parser("SELECT 'ééé'; SELECT b FROM t")
    expect(stmts).to eq(["SELECT 'ééé'", ' SELECT b FROM t'])
  end
end
