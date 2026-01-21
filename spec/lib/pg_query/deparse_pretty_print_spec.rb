require 'spec_helper'

describe PgQuery do
  describe '.deparse' do
    subject { PgQuery.parse(query).deparse(opts: PgQuery::DeparseOpts.new(pretty_print: true, comments: PgQuery.deparse_comments_for_query(query))) }

    context 'SELECT' do
      context 'basic statement' do
        let(:query) do
          <<~Q
            SELECT a AS b
            FROM x
            WHERE
                y = 5
                AND z = y
          Q
        end

        it { is_expected.to eq query.strip }
      end
    end

    context 'comments' do
      context 'multi-line' do
        let(:query) do
          <<~Q
            --
            -- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
            --

            COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST'
          Q
        end

        it { is_expected.to eq query.strip }
      end
    end
  end
end
