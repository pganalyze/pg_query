require 'spec_helper'

describe PgQuery do
  # Strings returned from the C extension
  let(:query) { "SELECT 'ä' /* é */" }

  it 'returns the normalized query as UTF-8' do
    normalized = described_class.normalize(query)
    expect(normalized.encoding).to eq Encoding::UTF_8
    expect(normalized).to eq 'SELECT $1 /* é */'
  end

  it 'returns the deparsed query as UTF-8' do
    deparsed = described_class.parse(query).deparse
    expect(deparsed.encoding).to eq Encoding::UTF_8
    expect(deparsed).to eq "SELECT 'ä'"
  end

  it 'returns deparse comments as UTF-8' do
    comment = described_class.deparse_comments_for_query(query).first
    expect(comment.str.encoding).to eq Encoding::UTF_8
    expect(comment.str).to eq '/* é */'
  end

  it 'returns error messages as UTF-8' do
    expect { described_class.parse('SELECT 1 FROM x ü ü') }.to raise_error(PgQuery::ParseError) do |error|
      expect(error.message.encoding).to eq Encoding::UTF_8
      expect(error.message).to start_with 'syntax error at or near "ü"'
    end
  end
end
