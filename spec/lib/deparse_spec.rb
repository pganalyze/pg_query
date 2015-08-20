require 'spec_helper'

describe PgQuery do
  let(:oneline_query) { query.gsub(/\s+/, ' ').gsub('( ', '(').gsub(' )', ')').strip.chomp(';') }
  let(:parsetree) { described_class.parse(oneline_query).parsetree }

  describe '.deparse' do
    subject { described_class.deparse(parsetree.first) }

    context 'SELECT' do
      context 'basic statement' do
        let(:query) { 'SELECT a AS b FROM x WHERE y = 5 AND z = y' }
        it { is_expected.to eq query }
      end

      context 'complex SELECT statement' do
        let(:query) { "SELECT memory_total_bytes, memory_swap_total_bytes - memory_swap_free_bytes AS swap, date_part(?, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON snapshot_id = s.id WHERE s.database_id = ? AND s.collected_at >= ? AND s.collected_at <= ? ORDER BY collected_at ASC" }
        it { is_expected.to eq query }
      end

      context 'simple WITH statement' do
        let(:query) { 'WITH t AS (SELECT random() AS x FROM generate_series(1, 3)) SELECT * FROM t' }
        it { is_expected.to eq query }
      end

      context 'complex WITH statement' do
        # Taken from http://www.postgresql.org/docs/9.1/static/queries-with.html
        let(:query) do
          """
          WITH RECURSIVE search_graph(id, link, data, depth, path, cycle) AS (
              SELECT g.id, g.link, g.data, 1,
                ARRAY[ROW(g.f1, g.f2)],
                false
              FROM graph g
            UNION ALL
              SELECT g.id, g.link, g.data, sg.depth + 1,
                path || ROW(g.f1, g.f2),
                ROW(g.f1, g.f2) = ANY(path)
              FROM graph g, search_graph sg
              WHERE g.id = sg.link AND NOT cycle
          )
          SELECT id, data, link FROM search_graph;
          """
        end
        it { is_expected.to eq oneline_query }
      end

      context 'SUM' do
        let(:query) { 'SELECT sum(price_cents) FROM products' }
        it { is_expected.to eq query }
      end

      context 'LATERAL' do
        let(:query) { 'SELECT m.name AS mname, pname FROM manufacturers m, LATERAL get_product_names(m.id) pname' }
        it { is_expected.to eq query }
      end

      context 'LATERAL JOIN' do
        let(:query) do
          """
          SELECT m.name AS mname, pname
            FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true
          """
        end
        it { is_expected.to eq oneline_query }
      end

      context 'omitted FROM clause' do
        let(:query) { 'SELECT 2 + 2' }
        it { is_expected.to eq query }
      end

      context 'IS NULL' do
        let(:query) { 'SELECT * FROM x WHERE y IS NULL' }
        it { is_expected.to eq query }
      end

      context 'IS NOT NULL' do
        let(:query) { 'SELECT * FROM x WHERE y IS NOT NULL' }
        it { is_expected.to eq query }
      end

      context 'COUNT' do
        let(:query) { 'SELECT count(*) FROM x WHERE y IS NOT NULL' }
        it { is_expected.to eq query }
      end

      context 'basic CASE WHEN statements' do
        let(:query) { "SELECT CASE WHEN a.status = 1 THEN 'active' WHEN a.status = 2 THEN 'inactive' END FROM accounts a" }
        it { is_expected.to eq query }
      end

      context 'CASE WHEN statements with ELSE clause' do
        let(:query) { "SELECT CASE WHEN a.status = 1 THEN 'active' WHEN a.status = 2 THEN 'inactive' ELSE 'unknown' END FROM accounts a" }
        it { is_expected.to eq query }
      end

      context 'CASE WHEN statements in WHERE clause' do
        let(:query) { "SELECT * FROM accounts WHERE status = CASE WHEN x = 1 THEN 'active' ELSE 'inactive' END" }
        it { is_expected.to eq query }
      end

      context 'CASE WHEN EXISTS' do
        let(:query) { "SELECT CASE WHEN EXISTS(SELECT 1) THEN 1 ELSE 2 END" }
        it { is_expected.to eq query }
      end

      context 'Subselect in SELECT clause' do
        let(:query) { "SELECT (SELECT 'x')" }
        it { is_expected.to eq query }
      end

      context 'Subselect in FROM clause' do
        let(:query) { "SELECT * FROM (SELECT generate_series(0, 100)) a" }
        it { is_expected.to eq query }
      end

      context 'IN expression' do
        let(:query) { "SELECT * FROM x WHERE id IN (1, 2, 3)" }
        it { is_expected.to eq query }
      end

      context 'IN expression Subselect' do
        let(:query) { "SELECT * FROM x WHERE id IN (SELECT id FROM account)" }
        it { is_expected.to eq query }
      end

      context 'Subselect JOIN' do
        let(:query) { "SELECT * FROM x JOIN (SELECT n FROM z) b ON a.id = b.id" }
        it { is_expected.to eq query }
      end

      context 'simple indirection' do
        let(:query) { "SELECT * FROM x WHERE y = z[?]" }
        it { is_expected.to eq query }
      end

      context 'complex indirection' do
        let(:query) { "SELECT * FROM x WHERE y = z[?][?]" }
        it { is_expected.to eq query }
      end

      context 'NOT' do
        let(:query) { "SELECT * FROM x WHERE NOT y" }
        it { is_expected.to eq query }
      end

      context 'OR' do
        let(:query) { "SELECT * FROM x WHERE x OR y" }
        it { is_expected.to eq query }
      end

      context 'OR with parens' do
        let(:query) { "SELECT 1 WHERE (1 = 1 OR 1 = 2) AND 1 = 2" }
        it { is_expected.to eq query }
      end

      context 'OR with nested AND' do
        let(:query) { "SELECT 1 WHERE (1 = 1 AND 2 = 2) OR 2 = 3" }
        it { is_expected.to eq query }
      end

      context 'OR with nested OR' do
        let(:query) { "SELECT 1 WHERE (1 = 1 OR 2 = 2) OR 2 = 3" }
        it { is_expected.to eq query }
      end

      context 'ANY' do
        let(:query) { "SELECT * FROM x WHERE x = ANY(?)" }
        it { is_expected.to eq query }
      end

      context 'COALESCE' do
        let(:query) { "SELECT * FROM x WHERE x = COALESCE(y, ?)" }
        it { is_expected.to eq query }
      end

      context 'GROUP BY' do
        let(:query) { "SELECT a, b, max(c) FROM c WHERE d = 1 GROUP BY a, b" }
        it { is_expected.to eq query }
      end
    end

    context 'type cast' do
      context 'simple case' do
        let(:query) { "SELECT 1::int8" }
        it { is_expected.to eq query }
      end

      context 'regclass' do
        let(:query) { "SELECT ?::regclass" }
        it { is_expected.to eq query }
      end
    end

    context 'param ref' do
      context 'normal param refs' do
        let(:query) { "SELECT $5" }
        it { is_expected.to eq query }
      end

      context 'query replacement character' do
        let(:query) { "SELECT ?" }
        it { is_expected.to eq query }
      end
    end

    context 'INSERT' do
      context 'basic' do
        let(:query) { "INSERT INTO x (y, z) VALUES (1, 'abc')" }
        it { is_expected.to eq query }
      end

      context 'INTO SELECT' do
        let(:query) { "INSERT INTO x SELECT * FROM y" }
        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          """
          WITH moved AS (
            DELETE
            FROM employees
            WHERE manager_name = 'Mary'
          )
          INSERT INTO employees_of_mary
          SELECT * FROM moved;
          """
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'UPDATE' do
      context 'basic' do
        let(:query) { "UPDATE x SET y = 1 WHERE z = 'abc'" }
        it { is_expected.to eq query }
      end

      context 'elaborate' do
        let(:query) do
          "UPDATE ONLY x table_x SET y = 1 WHERE z = 'abc' RETURNING y AS changed_y"
        end
        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          """
          WITH archived AS (
            DELETE
            FROM employees
            WHERE manager_name = 'Mary'
          )
          UPDATE users SET archived = true WHERE users.id IN (SELECT user_id FROM moved)
          """
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'DELETE' do
      context 'basic' do
        let(:query) { "DELETE FROM x WHERE y = 1" }
        it { is_expected.to eq query }
      end

      context 'elaborate' do
        let(:query) { "DELETE FROM ONLY x table_x USING table_z WHERE y = 1 RETURNING *" }
        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          """
          WITH archived AS (
            DELETE
            FROM employees
            WHERE manager_name = 'Mary'
          )
          DELETE FROM users WHERE users.id IN (SELECT user_id FROM moved)
          """
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'CREATE FUNCTION' do
      # Taken from http://www.postgresql.org/docs/8.3/static/queries-table-expressions.html
      context 'with inline function definition' do
        let(:query) do
          """
          CREATE FUNCTION getfoo(int) RETURNS SETOF users AS $$
              SELECT * FROM users WHERE users.id = $1;
          $$ language sql;
          """
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'CREATE TABLE' do
      context 'top-level' do
        let(:query) do
          """
            CREATE TABLE cities (
                name            text,
                population      real,
                altitude        double,
                identifier      smallint,
                postal_code     int,
                foreign_id      bigint
           );
          """
        end
        it { is_expected.to eq oneline_query }
      end

      context 'with alternate typecasts' do
        let(:query) do
          """
            CREATE TABLE types (a float(2), b float(49), c NUMERIC(2, 3), d character(4), e char(5), f varchar(6), g character varying(7));
          """
        end
        it do
          is_expected.to eq(
            "CREATE TABLE types (a real, b double, c numeric(2, 3), d char(4), e char(5), f varchar(6), g varchar(7))"
          )
        end
      end

      context 'with column definition options' do
        let(:query) do
          """
          CREATE TABLE tablename (
              colname int NOT NULL DEFAULT nextval('tablename_colname_seq')
          );
          """
        end
        it { is_expected.to eq oneline_query }
      end

      context 'inheriting' do
        let(:query) do
          """
            CREATE TABLE capitals (
                state           char(2)
            ) INHERITS (cities);
          """
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'TRANSACTION' do
      context 'BEGIN' do
        let(:query) { 'BEGIN' }
        it { is_expected.to eq query }
      end

      context 'ROLLBACK' do
        let(:query) { 'ROLLBACK' }
        it { is_expected.to eq query }
      end

      context 'COMMIT' do
        let(:query) { 'COMMIT' }
        it { is_expected.to eq query }
      end

      context 'SAVEPOINT' do
        let(:query) { 'SAVEPOINT x' }
        it { is_expected.to eq query }
      end

      context 'ROLLBACK TO SAFEPOINT' do
        let(:query) { 'ROLLBACK TO SAVEPOINT x' }
        it { is_expected.to eq query }
      end

      context 'RELEASE' do
        let(:query) { 'RELEASE x' }
        it { is_expected.to eq query }
      end
    end
  end

  describe '#deparse' do
    subject { described_class.parse(oneline_query).deparse }

    context 'for single query' do
      let(:query) do
        """
        SELECT m.name AS mname, pname
          FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true
        """
      end
      it { is_expected.to eq oneline_query }
    end

    context 'for multiple queries' do
      let(:query) do
        """
        SELECT m.name AS mname, pname
          FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true;
        INSERT INTO manufacturers_daily (a, b)
          SELECT a, b FROM manufacturers;
        """
      end
      it { is_expected.to eq oneline_query }
    end

    context 'for multiple queries with a semicolon inside a value' do
      let(:query) do
        """
        SELECT m.name AS mname, pname
          FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true;
        UPDATE users SET name = 'bobby; drop tables';
        INSERT INTO manufacturers_daily (a, b)
          SELECT a, b FROM manufacturers;
        """
      end
      it { is_expected.to eq oneline_query }
    end
  end
end
