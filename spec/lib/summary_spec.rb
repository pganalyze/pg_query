require 'spec_helper'

describe PgQuery, '.summary' do
  it 'summarizes a simple query' do
    summary = described_class.summary('SELECT * FROM test WHERE a = 1')

    expect(summary.query).to eq 'SELECT * FROM test WHERE a = 1'
    expect(summary.warnings).to eq []
    expect(summary.tables).to eq ['test']
    expect(summary.select_tables).to eq ['test']
    expect(summary.dml_tables).to eq []
    expect(summary.ddl_tables).to eq []
    expect(summary.aliases).to eq({})
    expect(summary.cte_names).to eq []
    expect(summary.functions).to eq []
    expect(summary.filter_columns).to eq [[nil, 'a']]
    expect(summary.statement_types).to eq ['SelectStmt']
    expect(summary.truncated_query).to be_nil
  end

  it 'summarizes an empty query' do
    summary = described_class.summary('-- nothing')

    expect(summary.warnings).to eq []
    expect(summary.tables).to eq []
    expect(summary.aliases).to eq({})
    expect(summary.cte_names).to eq []
    expect(summary.functions).to eq []
    expect(summary.filter_columns).to eq []
    expect(summary.statement_types).to eq []
  end

  it 'returns the raw protobuf result' do
    summary = described_class.summary('SELECT * FROM test')

    expect(summary.protobuf).to be_a PgQuery::SummaryResult
    expect(summary.protobuf.tables.first).to eq(
      PgQuery::SummaryResult::Table.new(name: 'test', table_name: 'test', context: :Select)
    )
  end

  it 'finds aliases' do
    summary = described_class.summary('SELECT * FROM test AS x WHERE a = 1')

    expect(summary.tables).to eq ['test']
    expect(summary.aliases).to eq('x' => 'test')
  end

  it 'finds tables in nested sub-selects' do
    summary = described_class.summary('SELECT * FROM test WHERE col1 = (SELECT col2 FROM test2 WHERE col3 = 123)')

    expect(summary.tables).to match_array %w[test test2]
    expect(summary.filter_columns).to match_array [[nil, 'col1'], [nil, 'col3']]
  end

  it 'finds tables in joins' do
    summary = described_class.summary('SELECT * FROM t0 JOIN t1 ON (t0.id = t1.id)')

    expect(summary.tables).to match_array %w[t0 t1]
  end

  it 'handles deeply nested queries that exceed the protobuf recursion limit of .parse' do
    query = 'SELECT * FROM t0 ' + (1..600).map { |i| "JOIN t#{i} ON (1)" }.join(' ')

    expect { described_class.parse(query) }.to raise_error(PgQuery::ParseError, /Failed to parse tree/)

    summary = described_class.summary(query)
    expect(summary.tables.size).to eq 601
    expect(summary.statement_types).to eq ['SelectStmt']
  end

  it 'keeps track of schema names' do
    summary = described_class.summary('SELECT * FROM public.test')

    expect(summary.tables).to eq ['public.test']
    expect(summary.tables_with_details).to eq [
      { name: 'public.test', type: :select, schemaname: 'public', relname: 'test' }
    ]
  end

  it 'excludes CTE names from tables' do
    summary = described_class.summary('WITH a AS (SELECT * FROM x) SELECT * FROM a')

    expect(summary.tables).to eq ['x']
    expect(summary.cte_names).to eq ['a']
  end

  it 'finds tables modified by DML statements' do
    summary = described_class.summary('INSERT INTO x (a) SELECT a FROM y')

    expect(summary.dml_tables).to eq ['x']
    expect(summary.select_tables).to eq ['y']
    expect(summary.statement_types).to eq ['InsertStmt', 'SelectStmt']
  end

  # Note that the source table (src) is not reported, since the C implementation only
  # looks at the target relation of a MERGE. PgQuery.parse reports neither of the two.
  it 'finds the target table of MERGE statements' do
    summary = described_class.summary('MERGE INTO tgt USING src ON tgt.id = src.id WHEN MATCHED THEN UPDATE SET a = src.a')

    expect(summary.tables).to eq ['tgt']
    expect(summary.dml_tables).to eq ['tgt']
    expect(summary.statement_types).to eq ['MergeStmt']
  end

  it 'finds tables modified by DDL statements' do
    summary = described_class.summary('ALTER TABLE test ADD PRIMARY KEY (gid)')

    expect(summary.ddl_tables).to eq ['test']
    expect(summary.tables_with_details).to eq [
      { name: 'test', type: :ddl, schemaname: nil, relname: 'test' }
    ]
    expect(summary.statement_types).to eq ['AlterTableStmt']
  end

  it 'finds called functions' do
    summary = described_class.summary('SELECT foo.testfunc(1), lower(name) FROM x')

    expect(summary.functions).to match_array ['foo.testfunc', 'lower']
    expect(summary.call_functions).to match_array ['foo.testfunc', 'lower']
    expect(summary.ddl_functions).to eq []
    expect(summary.functions_with_details).to match_array [
      { function: 'foo.testfunc', type: :call, schemaname: 'foo', funcname: 'testfunc' },
      { function: 'lower', type: :call, schemaname: nil, funcname: 'lower' }
    ]
  end

  it 'finds functions defined by DDL statements' do
    summary = described_class.summary('CREATE FUNCTION foo.testfunc(x int) RETURNS int AS $$ SELECT x $$ LANGUAGE SQL')

    expect(summary.functions).to eq ['foo.testfunc']
    expect(summary.ddl_functions).to eq ['foo.testfunc']
    expect(summary.call_functions).to eq []
  end

  it 'summarizes multi-statement queries' do
    summary = described_class.summary('SELECT * FROM x; INSERT INTO y (a) VALUES (1); CREATE TABLE z (id int)')

    expect(summary.select_tables).to eq ['x']
    expect(summary.dml_tables).to eq ['y']
    expect(summary.ddl_tables).to eq ['z']
    expect(summary.statement_types).to eq ['SelectStmt', 'InsertStmt', 'CreateStmt']
  end

  it 'raises a parse error for invalid queries' do
    expect { described_class.summary('SELECT \'ERR') }.to raise_error(PgQuery::ParseError, /unterminated quoted string/)
    expect { described_class.summary('CREATE RANDOM ix_test ON contacts.person') }.to raise_error(PgQuery::ParseError) do |error|
      expect(error.message).to include 'syntax error at or near "RANDOM"'
      expect(error.location).to eq 8
    end
  end

  describe 'truncation' do
    it 'does not truncate by default' do
      expect(described_class.summary('SELECT a, b, c, d, e, f FROM xyz WHERE a = b').truncated_query).to be_nil
    end

    it 'omits the target list' do
      query = 'SELECT a, b, c, d, e, f FROM xyz WHERE a = b'
      expect(described_class.summary(query, truncate_limit: 40).truncated_query).to eq 'SELECT ... FROM xyz WHERE a = b'
    end

    it 'omits part of CTEs' do
      query = 'WITH x AS (SELECT * FROM y) SELECT * FROM x'
      expect(described_class.summary(query, truncate_limit: 40).truncated_query).to eq 'WITH x AS (...) SELECT * FROM x'
    end

    it 'omits the where clause' do
      query = 'SELECT * FROM z WHERE a = b AND x = y'
      expect(described_class.summary(query, truncate_limit: 30).truncated_query).to eq 'SELECT * FROM z WHERE ...'
    end

    it 'performs a simple truncation if necessary' do
      expect(described_class.summary('SELECT * FROM t', truncate_limit: 10).truncated_query).to eq 'SELECT ...'
    end

    it 'returns the deparsed query if it is short enough' do
      expect(described_class.summary('SELECT * FROM t', truncate_limit: 100).truncated_query).to eq 'SELECT * FROM t'
    end

    it 'returns an empty string for a query that deparses to nothing' do
      expect(described_class.summary('-- nothing', truncate_limit: 10).truncated_query).to eq ''
    end

    context 'with multi-byte characters' do
      # The CTE name mixes kanji and katakana, both of which are three bytes per
      # character in UTF-8, so that a cut based on byte offsets lands in the middle
      # of a character.
      let(:query) { 'WITH "都道府県別ストア別月次売上集計" AS (SELECT) SELECT w' }

      it 'never truncates in the middle of a character' do
        (10..45).each do |limit|
          truncated = described_class.summary(query, truncate_limit: limit).truncated_query

          expect(truncated.encoding).to eq Encoding::UTF_8
          expect(truncated).to be_valid_encoding
          expect(truncated.length).to be <= limit
        end
      end

      it 'truncates the query' do
        expect(described_class.summary(query, truncate_limit: 21).truncated_query).to eq 'WITH "都道府県別ストア別月次売...'
        expect(described_class.summary(query, truncate_limit: 40).truncated_query).to eq 'WITH "都道府県別ストア別月次売上集計" AS (...) SELECT w'
      end

      # The C implementation checks whether the query still needs truncating based on its
      # length in bytes, but performs the final cut based on its length in characters, so
      # the result can be shorter than the one PgQuery.parse(...).truncate returns.
      it 'is a known difference to .parse for limits between the byte and character length' do
        expect(described_class.summary(query, truncate_limit: 22).truncated_query).to eq 'WITH "都道府県別ストア別月次売...'
        expect(described_class.parse(query).truncate(22)).to eq 'WITH "都道府県別ストア別月次売上...'
      end
    end
  end

  describe 'filter columns' do
    def filter_columns(query)
      described_class.summary(query).filter_columns
    end

    it 'finds unqualified names' do
      expect(filter_columns('SELECT * FROM x WHERE y = $1 AND z = 1')).to eq [[nil, 'y'], [nil, 'z']]
    end

    it 'finds qualified names' do
      expect(filter_columns('SELECT * FROM x WHERE x.y = $1 AND x.z = 1')).to eq [['x', 'y'], ['x', 'z']]
    end

    it 'resolves aliases to the table name' do
      expect(filter_columns('SELECT * FROM x AS a WHERE a.y = $1')).to eq [['x', 'y']]
    end

    it 'traverses into CTEs' do
      query = 'WITH a AS (SELECT * FROM x WHERE x.y = $1 AND x.z = 1) SELECT * FROM a WHERE b = 5'
      expect(filter_columns(query)).to match_array [['x', 'y'], ['x', 'z'], [nil, 'b']]
    end

    it 'recognizes boolean tests' do
      expect(filter_columns('SELECT * FROM x WHERE x.y IS TRUE AND x.z IS NOT FALSE')).to eq [['x', 'y'], ['x', 'z']]
    end

    it 'recognizes null tests' do
      expect(filter_columns('SELECT * FROM x WHERE x.y IS NULL AND x.z IS NOT NULL')).to eq [['x', 'y'], ['x', 'z']]
    end

    it 'finds COALESCE argument names' do
      expect(filter_columns('SELECT * FROM x WHERE x.y = COALESCE(z.a, z.b)')).to eq [['x', 'y'], ['z', 'a'], ['z', 'b']]
    end

    it 'ignores target list columns' do
      expect(filter_columns('SELECT a, y, z FROM x WHERE x.y = $1')).to eq [['x', 'y']]
    end

    it 'ignores ORDER BY columns' do
      expect(filter_columns('SELECT * FROM x WHERE x.y = $1 ORDER BY a, b')).to eq [['x', 'y']]
    end

    ['UNION', 'UNION ALL', 'EXCEPT', 'EXCEPT ALL', 'INTERSECT', 'INTERSECT ALL'].each do |combiner|
      it "finds unqualified names in #{combiner} query" do
        query = "SELECT * FROM x where y = $1 #{combiner} SELECT * FROM x where z = $2"
        expect(filter_columns(query)).to eq [[nil, 'y'], [nil, 'z']]
      end
    end

    # These are known differences to PgQuery.parse(...).filter_columns, caused by the
    # C implementation only collecting filter columns from SELECT WHERE clauses.
    context 'known differences to .parse' do
      it 'does not include JOIN conditions' do
        query = 'SELECT * FROM x JOIN y ON (x.id = y.x_id)'
        expect(filter_columns(query)).to eq []
        expect(described_class.parse(query).filter_columns).to match_array [['x', 'id'], ['y', 'x_id']]
      end

      it 'does not include the WHERE clause of UPDATE statements' do
        query = 'UPDATE x SET a = 1 WHERE x.b = $1'
        expect(filter_columns(query)).to eq []
        expect(described_class.parse(query).filter_columns).to eq [['x', 'b']]
      end

      it 'does not include the WHERE clause of DELETE statements' do
        query = 'DELETE FROM x WHERE x.b = $1'
        expect(filter_columns(query)).to eq []
        expect(described_class.parse(query).filter_columns).to eq [['x', 'b']]
      end

      it 'includes the WHERE clause of a SELECT inside an INSERT' do
        query = 'INSERT INTO x (a) SELECT a FROM y WHERE y.b = $1'
        expect(filter_columns(query)).to eq [['y', 'b']]
        expect(described_class.parse(query).filter_columns).to eq []
      end
    end
  end

  describe 'compatibility with .parse' do
    queries = [
      'SELECT * FROM test AS x WHERE a = 1',
      'SELECT memory_total_bytes, (memory_swap_total_bytes - memory_swap_free_bytes) AS swap, ' \
      'date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON (snapshot_id = s.id) ' \
      'WHERE s.database_id = $0 AND s.collected_at BETWEEN $0 AND $0 ORDER BY collected_at',
      'WITH a AS (SELECT * FROM x WHERE x.y = $1) SELECT * FROM a WHERE b = 5',
      'INSERT INTO x (a) SELECT a FROM y WHERE y.b = $1',
      'UPDATE x SET a = 1 WHERE x.b = $1',
      'DELETE FROM x WHERE x.b = $1',
      'CREATE TABLE test (id int)',
      'DROP TABLE test'
    ]

    # Note that filter_columns is intentionally not compared here, see the
    # "known differences to .parse" tests above.
    queries.each do |query|
      it "matches .parse for #{query}" do
        summary = described_class.summary(query)
        parsed = described_class.parse(query)

        expect(summary.tables).to match_array parsed.tables
        expect(summary.select_tables).to match_array parsed.select_tables
        expect(summary.dml_tables).to match_array parsed.dml_tables
        expect(summary.ddl_tables).to match_array parsed.ddl_tables
        expect(summary.functions).to match_array parsed.functions
        expect(summary.call_functions).to match_array parsed.call_functions
        expect(summary.ddl_functions).to match_array parsed.ddl_functions
        expect(summary.cte_names).to match_array parsed.cte_names
        expect(summary.aliases).to eq parsed.aliases
      end
    end
  end
end
