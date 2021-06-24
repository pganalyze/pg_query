require 'spec_helper'

describe PgQuery do
  let(:oneline_query) { query.gsub(/\s+/, ' ').gsub('( ', '(').gsub(' )', ')').strip.chomp(';') }

  describe '.deparse' do
    subject { PgQuery.parse(query).deparse }

    context 'bad parse trees' do
      it 'raises an error in deparseTargetList when res target misses val' do
        tree = PgQuery::ParseResult.new(
          stmts: [
            PgQuery::RawStmt.new(
              stmt: PgQuery::Node.from(
                PgQuery::SelectStmt.new(
                  target_list: [
                    PgQuery::Node.from(PgQuery::ResTarget.new(name: 'a'))
                  ],
                  op: :SETOP_NONE
                )
              )
            )
          ]
        )

        expect { PgQuery.deparse(tree) }.to raise_error do |error|
          expect(error).to be_a(described_class::ParseError)
          expect(error.message).to eq "deparse error in deparseTargetList: ResTarget without val (pg_query_deparse.c:1419)"
        end
      end
    end
  end
end
