require 'spec_helper'

describe PgQuery, '.scan' do
  it "scans a simple query and returns the tokens" do
    result, stderr = described_class.scan("SELECT 1")
    expect(result.tokens).to eq([
      PgQuery::ScanToken.new(start: 0, end: 6, token: :SELECT, keyword_kind: :RESERVED_KEYWORD),
      PgQuery::ScanToken.new(start: 7, end: 8, token: :ICONST, keyword_kind: :NO_KEYWORD)
    ])
  end

  it "scans comments" do
    result, stderr = described_class.scan("SELECT /*comment1*/ 1--comment2")
    expect(result.tokens).to eq([
      PgQuery::ScanToken.new(start: 0, end: 6, token: :SELECT, keyword_kind: :RESERVED_KEYWORD),
      PgQuery::ScanToken.new(start: 7, end: 19, token: :C_COMMENT, keyword_kind: :NO_KEYWORD),
      PgQuery::ScanToken.new(start: 20, end: 21, token: :ICONST, keyword_kind: :NO_KEYWORD),
      PgQuery::ScanToken.new(start: 21, end: 31, token: :SQL_COMMENT, keyword_kind: :NO_KEYWORD)
    ])
  end
end