require 'spec_helper'

describe PgQuery do
  let(:oneline_query) { query.gsub(/\s+/, ' ').gsub('( ', '(').gsub(' )', ')').strip.chomp(';') }

  describe '.deparse' do
    subject { PgQuery.parse(query).deparse }

    context 'SELECT' do
      context 'basic statement' do
        let(:query) { 'SELECT a AS b FROM x WHERE y = 5 AND z = y' }

        it { is_expected.to eq query }
      end

      context 'with empty target list' do
        let(:query) { 'SELECT FROM x WHERE y = 5 AND z = y' }

        it { is_expected.to eq query }
      end

      context 'basic statement with schema' do
        let(:query) { 'SELECT a AS b FROM public.x WHERE y = 5 AND z = y' }

        it { is_expected.to eq query }
      end

      context 'with DISTINCT' do
        let(:query) { 'SELECT DISTINCT a, b, * FROM c WHERE d = e' }

        it { is_expected.to eq query }
      end

      context 'with DISTINCT ON' do
        let(:query) { 'SELECT DISTINCT ON (a) a, b FROM c' }

        it { is_expected.to eq query }
      end

      context 'with INTO' do
        let(:query) { 'SELECT * INTO films_recent FROM films WHERE date_prod >= \'2002-01-01\'' }

        it { is_expected.to eq query }
      end

      context 'SQL value function' do
        let(:query) { 'SELECT current_timestamp' }

        it { is_expected.to eq query }
      end

      context 'SQL value function with precision' do
        let(:query) { 'SELECT current_time(2)' }

        it { is_expected.to eq query }
      end

      context 'complex SELECT statement' do
        let(:query) { 'SELECT memory_total_bytes, memory_swap_total_bytes - memory_swap_free_bytes AS swap, date_part($1, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON snapshot_id = s.id WHERE s.database_id = $2 AND s.collected_at >= $3 AND s.collected_at <= $4 ORDER BY collected_at ASC' }

        it { is_expected.to eq query }
      end

      context 'ORDER BY with NULLS FIRST' do
        let(:query) { 'SELECT * FROM a ORDER BY x ASC NULLS FIRST' }

        it { is_expected.to eq query }
      end

      context 'ORDER BY with NULLS LAST' do
        let(:query) { 'SELECT * FROM a ORDER BY x ASC NULLS LAST' }

        it { is_expected.to eq query }
      end

      context 'ORDER BY with COLLATE' do
        let(:query) { 'SELECT * FROM a ORDER BY x COLLATE "tr_TR" DESC NULLS LAST' }

        it { is_expected.to eq query }
      end

      context 'text with COLLATE' do
        let(:query) { "SELECT 'foo' COLLATE \"tr_TR\"" }

        it { is_expected.to eq query }
      end

      context 'UNION or UNION ALL' do
        let(:query) { 'WITH kodsis AS (SELECT * FROM application), kodsis2 AS (SELECT * FROM application) SELECT * FROM kodsis UNION SELECT * FROM kodsis ORDER BY id DESC' }

        it { is_expected.to eq query }
      end

      context 'UNION with ORDER' do
        let(:query) { 'SELECT id, name FROM table1 UNION (SELECT id, name FROM table2 ORDER BY name) ORDER BY id ASC' }

        it { is_expected.to eq query }
      end

      context 'EXCEPT' do
        let(:query) { "SELECT a FROM kodsis EXCEPT SELECT a FROM application" }

        it { is_expected.to eq query }
      end

      context 'INTERSECT' do
        let(:query) { "SELECT 'a' INTERSECT SELECT 'b'" }

        it { is_expected.to eq query }
      end

      context 'with specific column alias' do
        let(:query) { "SELECT * FROM (VALUES ('anne', 'smith'), ('bob', 'jones'), ('joe', 'blow')) names(first, last)" }

        it { is_expected.to eq oneline_query }
      end

      context 'with LIKE filter' do
        let(:query) { "SELECT * FROM users WHERE name LIKE 'postgresql:%';" }

        it { is_expected.to eq oneline_query }
      end

      context 'with NOT LIKE filter' do
        let(:query) { "SELECT * FROM users WHERE name NOT LIKE 'postgresql:%';" }

        it { is_expected.to eq oneline_query }
      end

      context 'with ILIKE filter' do
        let(:query) { "SELECT * FROM users WHERE name ILIKE 'postgresql:%';" }

        it { is_expected.to eq oneline_query }
      end

      context 'with NOT ILIKE filter' do
        let(:query) { "SELECT * FROM users WHERE name NOT ILIKE 'postgresql:%';" }

        it { is_expected.to eq oneline_query }
      end

      context 'simple WITH statement' do
        let(:query) { 'WITH t AS (SELECT random() AS x FROM generate_series(1, 3)) SELECT * FROM t' }

        it { is_expected.to eq query }
      end

      context 'complex WITH statement' do
        # Taken from http://www.postgresql.org/docs/9.1/static/queries-with.html
        let(:query) do
          %(
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
          )
        end

        it { is_expected.to eq oneline_query }
      end

      context 'OVERLAY' do
        let(:query) { 'SELECT OVERLAY(m.name PLACING \'******\' FROM 3 FOR 6) AS tc_kimlik FROM tb_test m' }

        it { is_expected.to eq query }
      end

      context 'SUM' do
        let(:query) { 'SELECT sum(price_cents) FROM products' }

        it { is_expected.to eq query }
      end

      context 'ARRAY' do
        let(:query) { 'SELECT ARRAY(SELECT id FROM products)::bigint[]' }

        it { is_expected.to eq query }
      end

      context 'LATERAL' do
        let(:query) { 'SELECT m.name AS mname, pname FROM manufacturers m, LATERAL get_product_names(m.id) pname' }

        it { is_expected.to eq query }
      end

      context 'LATERAL JOIN' do
        let(:query) do
          %(
          SELECT m.name AS mname, pname
            FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true
          )
        end

        it { is_expected.to eq oneline_query }
      end

      context 'LATERAL JOIN with sql' do
        let(:query) do
          %(
          SELECT *
                  FROM tb_test_main mh
                  JOIN LATERAL (
                    SELECT ftnrm.* FROM test ftnrm WHERE ftnrm.hizmet_id = mh.id
                    UNION ALL
                    SELECT ftarc.* FROM test.test2 ftarc WHERE ftarc.hizmet_id = mh.id
                  ) ft ON true
          )
        end

        it { is_expected.to eq oneline_query }
      end

      context 'CROSS JOIN' do
        let(:query) do
          'SELECT x, y FROM a CROSS JOIN b'
        end

        it { is_expected.to eq query }
      end

      context 'NATURAL JOIN' do
        let(:query) { 'SELECT x, y FROM a NATURAL JOIN b' }

        it { is_expected.to eq query }
      end

      context 'LEFT JOIN' do
        let(:query) { 'SELECT x, y FROM a LEFT JOIN b ON 1 > 0' }

        it { is_expected.to eq query }
      end

      context 'RIGHT JOIN' do
        let(:query) { 'SELECT x, y FROM a RIGHT JOIN b ON 1 > 0' }

        it { is_expected.to eq query }
      end

      context 'FULL JOIN' do
        let(:query) { 'SELECT x, y FROM a FULL JOIN b ON 1 > 0' }

        it { is_expected.to eq query }
      end

      context 'JOIN with USING' do
        let(:query) do
          'SELECT x, y FROM a JOIN b USING (z)'
        end

        it { is_expected.to eq query }
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

      context 'COUNT DISTINCT' do
        let(:query) { 'SELECT count(DISTINCT a) FROM x WHERE y IS NOT NULL' }

        it { is_expected.to eq query }
      end

      context 'basic CASE WHEN statements' do
        let(:query) { 'SELECT CASE WHEN a.status = 1 THEN \'active\' WHEN a.status = 2 THEN \'inactive\' END FROM accounts a' }

        it { is_expected.to eq query }
      end

      context 'CASE condition WHEN clause' do
        let(:query) { 'SELECT CASE 1 > 0 WHEN true THEN \'ok\' ELSE NULL END' }

        it { is_expected.to eq query }
      end

      context 'CASE WHEN statements with ELSE clause' do
        let(:query) { 'SELECT CASE WHEN a.status = 1 THEN \'active\' WHEN a.status = 2 THEN \'inactive\' ELSE \'unknown\' END FROM accounts a' }

        it { is_expected.to eq query }
      end

      context 'CASE WHEN statements in WHERE clause' do
        let(:query) { 'SELECT * FROM accounts WHERE status = CASE WHEN x = 1 THEN \'active\' ELSE \'inactive\' END' }

        it { is_expected.to eq query }
      end

      context 'CASE WHEN EXISTS' do
        let(:query) { "SELECT CASE WHEN EXISTS (SELECT 1) THEN 1 ELSE 2 END" }

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
        let(:query) { 'SELECT * FROM x WHERE id IN (1, 2, 3)' }

        it { is_expected.to eq query }
      end

      context 'IN expression Subselect' do
        let(:query) { 'SELECT * FROM x WHERE id IN (SELECT id FROM account)' }

        it { is_expected.to eq query }
      end

      context 'NOT IN expression' do
        let(:query) { 'SELECT * FROM x WHERE id NOT IN (1, 2, 3)' }

        it { is_expected.to eq query }
      end

      context 'Subselect JOIN' do
        let(:query) { 'SELECT * FROM x JOIN (SELECT n FROM z) b ON a.id = b.id' }

        it { is_expected.to eq query }
      end

      context 'simple indirection' do
        let(:query) { 'SELECT * FROM x WHERE y = z[$1]' }

        it { is_expected.to eq query }
      end

      context 'query indirection' do
        let(:query) { 'SELECT (foo(1)).y' }

        it { is_expected.to eq query }
      end

      context 'array indirection' do
        let(:query) { "SELECT proname, (SELECT regexp_split_to_array(proargtypes::text, ' ') )[idx] AS argtype, proargnames[idx] AS argname FROM pg_proc" }

        it { is_expected.to eq oneline_query }
      end

      context 'sub query indirection' do
        let(:query) { "SELECT COALESCE((SELECT customer.sp_person(n.id) AS sp_person).city_id, NULL::int) AS city_id FROM customer.tb_customer n" }

        it { is_expected.to eq query }
      end

      context 'complex indirection' do
        let(:query) { 'SELECT * FROM x WHERE y = z[$1][$2]' }

        it { is_expected.to eq query }
      end

      context 'indirection with star' do
        let(:query) { 'SELECT (k #= hstore(\'{id}\'::text[], ARRAY[1::text])).* FROM test k' }

        it { is_expected.to eq query }
      end

      context 'NOT' do
        let(:query) { 'SELECT * FROM x WHERE NOT y' }

        it { is_expected.to eq query }
      end

      context 'OR' do
        let(:query) { 'SELECT * FROM x WHERE x OR y' }

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
        let(:query) { "SELECT 1 WHERE 1 = 1 OR 2 = 2 OR 2 = 3" }

        it { is_expected.to eq query }
      end

      context 'ALL' do
        let(:query) { 'SELECT * FROM x WHERE x = ALL($1)' }

        it { is_expected.to eq query }
      end

      context 'ANY' do
        let(:query) { 'SELECT * FROM x WHERE x = ANY($1)' }

        it { is_expected.to eq query }
      end

      context 'COALESCE' do
        let(:query) { 'SELECT * FROM x WHERE x = COALESCE(y, $1)' }

        it { is_expected.to eq query }
      end

      context 'GROUP BY' do
        let(:query) { 'SELECT a, b, max(c) FROM c WHERE d = 1 GROUP BY a, b' }

        it { is_expected.to eq query }
      end

      context 'LIMIT' do
        let(:query) { 'SELECT * FROM x LIMIT 50' }

        it { is_expected.to eq query }
      end

      context 'OFFSET' do
        let(:query) { 'SELECT * FROM x OFFSET 50' }

        it { is_expected.to eq query }
      end

      context 'FLOAT' do
        let(:query) { 'SELECT amount * 0.5' }

        it { is_expected.to eq query }
      end

      context 'BETWEEN' do
        let(:query) { 'SELECT * FROM x WHERE x BETWEEN \'2016-01-01\' AND \'2016-02-02\'' }

        it { is_expected.to eq query }
      end

      context 'NOT BETWEEN' do
        let(:query) { 'SELECT * FROM x WHERE x NOT BETWEEN \'2016-01-01\' AND \'2016-02-02\'' }

        it { is_expected.to eq query }
      end

      context 'BETWEEN SYMMETRIC' do
        let(:query) { 'SELECT * FROM x WHERE x BETWEEN SYMMETRIC 20 AND 10' }

        it { is_expected.to eq query }
      end

      context 'NOT BETWEEN SYMMETRIC' do
        let(:query) { 'SELECT * FROM x WHERE x NOT BETWEEN SYMMETRIC 20 AND 10' }

        it { is_expected.to eq query }
      end

      context 'NULLIF' do
        let(:query) { 'SELECT NULLIF(id, 0) AS id FROM x' }

        it { is_expected.to eq query }
      end

      context 'return NULL' do
        let(:query) { 'SELECT NULL FROM x' }

        it { is_expected.to eq query }
      end

      context 'IS true' do
        let(:query) { 'SELECT * FROM x WHERE y IS TRUE' }

        it { is_expected.to eq query }
      end

      context 'IS NOT true' do
        let(:query) { 'SELECT * FROM x WHERE y IS NOT TRUE' }

        it { is_expected.to eq query }
      end

      context 'IS false' do
        let(:query) { 'SELECT * FROM x WHERE y IS FALSE' }

        it { is_expected.to eq query }
      end

      context 'IS NOT false' do
        let(:query) { 'SELECT * FROM x WHERE y IS NOT FALSE' }

        it { is_expected.to eq query }
      end

      context 'IS unknown' do
        let(:query) { 'SELECT * FROM x WHERE y IS UNKNOWN' }

        it { is_expected.to eq query }
      end

      context 'IS NOT unknown' do
        let(:query) { 'SELECT * FROM x WHERE y IS NOT UNKNOWN' }

        it { is_expected.to eq query }
      end

      context 'with columndef list' do
        let(:query) do
          %q{
          SELECT * FROM crosstab(
          'SELECT "department", "role", COUNT("id") FROM "users" GROUP BY "department", "role" ORDER BY "department", "role"',
          'VALUES (''admin''::text), (''ordinary''::text)')
          AS (department varchar, admin int, ordinary int)
          }
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with columndef list and alias' do
        let(:query) do
          %q{
          SELECT * FROM crosstab(
          'SELECT "department", "role", COUNT("id") FROM "users" GROUP BY "department", "role" ORDER BY "department", "role"',
          'VALUES (''admin''::text), (''ordinary''::text)')
          ctab (department varchar, admin int, ordinary int)
          }
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with columndef list returning an array' do
        let(:query) do
          "
          SELECT row_cols[0] AS dept, row_cols[1] AS sub, admin, ordinary FROM crosstab(
          'SELECT ARRAY[department, sub] AS row_cols, role, COUNT(id) FROM users GROUP BY department, role ORDER BY department, role',
          'VALUES (''admin''::text), (''ordinary''::text)')
          AS (row_cols varchar[], admin int, ordinary int)
          "
        end

        it { is_expected.to eq oneline_query }
      end
    end

    context 'type cast' do
      context 'simple case' do
        let(:query) { "SELECT 1::int8" }

        it { is_expected.to eq query }
      end

      context 'with parentheses' do
        let(:query) { "SELECT CAST(1 + 3 AS int8)" }

        it { is_expected.to eq query }
      end

      context 'regclass' do
        let(:query) { "SELECT $1::regclass" }

        it { is_expected.to eq query }
      end

      context 'boolean column reference' do
        let(:query) { "SELECT table_field::bool, table_field::boolean FROM t" }

        it { is_expected.to eq query }
      end

      context 'boolean bool value cast' do
        let(:query) { "SELECT true, false" }

        it { is_expected.to eq query }
      end

      context 'boolean string value cast' do
        let(:query) { "SELECT 't'::boolean, 'f'::boolean" }

        # The AST is identical to the more common "SELECT true" case, which is why we return the short-form in that case
        it { is_expected.to eq "SELECT true, false" }
      end

      context 'boolean integer value cast' do
        let(:query) { "SELECT 1::boolean, 0::boolean" }

        it { is_expected.to eq query }
      end
    end

    context 'param ref' do
      let(:query) { "SELECT $5" }

      it { is_expected.to eq query }
    end

    context 'INSERT' do
      context 'basic' do
        let(:query) { 'INSERT INTO x (y, z) VALUES (1, \'abc\')' }

        it { is_expected.to eq query }
      end

      context 'special column name' do
        let(:query) { 'INSERT INTO x ("user") VALUES (\'abc\')' }

        it { is_expected.to eq query }
      end

      context 'with RETURNING' do
        let(:query) { 'INSERT INTO x (y, z) VALUES (1, \'abc\') RETURNING id' }

        it { is_expected.to eq query }
      end

      context 'INTO SELECT' do
        let(:query) { 'INSERT INTO x SELECT * FROM y' }

        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          '''
          WITH moved AS (
            DELETE
            FROM employees
            WHERE manager_name = \'Mary\'
          )
          INSERT INTO employees_of_mary
          SELECT * FROM moved;
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'ON CONFLICT' do
        let(:query) { 'INSERT INTO x (y, z) VALUES (1, \'abc\') ON CONFLICT (y) DO UPDATE SET "user" = excluded."user" RETURNING y' }

        it { is_expected.to eq query }
      end

      context 'ON CONFLICT DO NOTHING' do
        let(:query) { 'INSERT INTO x (y, z) VALUES (1, \'abc\') ON CONFLICT (y) DO NOTHING RETURNING y' }

        it { is_expected.to eq query }
      end

      context 'ON CONFLICT DO NOTHING with WHERE clause' do
        let(:query) { 'INSERT INTO distributors (did, dname) VALUES (10, \'Conrad International\') ON CONFLICT (did) WHERE is_active DO NOTHING' }

        it { is_expected.to eq query }
      end

      context 'ON CONFLICT DO NOTHING on CONSTRAINT' do
        let(:query) { 'INSERT INTO distributors (did, dname) VALUES (9, \'Antwerp Design\') ON CONFLICT ON CONSTRAINT distributors_pkey DO NOTHING' }

        it { is_expected.to eq query }
      end

      context 'HAVING' do
        let(:query) do
          '''
          INSERT INTO employees
          SELECT * FROM people
          WHERE 1 = 1
          GROUP BY name
          HAVING count(name) > 1
          ORDER BY name DESC
          LIMIT 10
          OFFSET 15
          FOR UPDATE
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'DEFAULT' do
        let(:query) { "INSERT INTO films VALUES ('T_601', 'Yojimbo', 106, DEFAULT, 'Drama', DEFAULT)" }

        it { is_expected.to eq query }
      end

      context 'with locks' do
        let(:query) do
          '''
          SELECT * FROM people FOR UPDATE OF name, email
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with cast varchar' do
        let(:query) do
          '''
          SELECT name::varchar(255) FROM people
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with cast varchar and no arguments' do
        let(:query) do
          '''
          SELECT name::varchar FROM people
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with cast numeric' do
        let(:query) do
          '''
          SELECT age::numeric(5, 2) FROM people
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with cast numeric and no arguments' do
        let(:query) do
          '''
          SELECT age::numeric FROM people
          '''
        end

        it { is_expected.to eq oneline_query }
      end
    end

    context 'UPDATE' do
      context 'basic' do
        let(:query) { 'UPDATE x SET y = 1 WHERE z = \'abc\'' }

        it { is_expected.to eq query }
      end

      context 'elaborate' do
        let(:query) do
          'UPDATE ONLY x table_x SET y = 1 WHERE z = \'abc\' RETURNING y AS changed_y'
        end

        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          '''
          WITH archived AS (
            DELETE
            FROM employees
            WHERE manager_name = \'Mary\'
          )
          UPDATE users SET archived = true WHERE users.id IN (SELECT user_id FROM moved)
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'WITH FROM UPDATE' do
        let(:query) do
          '''
          WITH archived AS (
            DELETE
            FROM employees
            WHERE manager_name = \'Mary\'
            RETURNING user_id
          )
          UPDATE users SET archived = true FROM archived WHERE archived.user_id = id RETURNING id
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'from generated sequence' do
        let(:query) do
          '''
            INSERT INTO jackdanger_card_totals (id, amount_cents, created_at)
            SELECT
              series.i,
              random() * 1000,
              (SELECT
                 \'2015-08-25 00:00:00 -0700\'::timestamp +
                ((\'2015-08-25 23:59:59 -0700\'::timestamp - \'2015-08-25 00:00:00 -0700\'::timestamp) * random()))
              FROM generate_series(1, 10000) series(i);
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'multiple columns' do
        let(:query) { 'UPDATE foo SET a = $1, b = $2' }

        it { is_expected.to eq oneline_query }
      end

      context 'special column name' do
        let(:query) { "UPDATE x SET \"user\" = 'emin'" }

        it { is_expected.to eq query }
      end
    end

    context 'DELETE' do
      context 'basic' do
        let(:query) { 'DELETE FROM x WHERE y = 1' }

        it { is_expected.to eq query }
      end

      context 'elaborate' do
        let(:query) { 'DELETE FROM ONLY x table_x USING table_z WHERE y = 1 RETURNING *' }

        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          '''
          WITH archived AS (
            DELETE
            FROM employees
            WHERE manager_name = \'Mary\'
          )
          DELETE FROM users WHERE users.id IN (SELECT user_id FROM moved)
          '''
        end

        it { is_expected.to eq oneline_query }
      end
    end

    context 'CREATE CAST' do
      context 'with function' do
        let(:query) do
          """
          CREATE CAST (bigint AS int4) WITH FUNCTION int4(bigint) AS ASSIGNMENT
          """.strip
        end

        it { is_expected.to eq query }
      end
      context 'without function' do
        let(:query) do
          """
          CREATE CAST (bigint AS int4) WITHOUT FUNCTION AS IMPLICIT
          """.strip
        end

        it { is_expected.to eq query }
      end
      context 'with inout' do
        let(:query) do
          """
          CREATE CAST (bigint AS int4) WITH INOUT AS ASSIGNMENT
          """.strip
        end

        it { is_expected.to eq query }
      end
    end

    context 'CREATE DOMAIN' do
      context 'with check' do
        let(:query) do
          """
          CREATE DOMAIN us_postal_code AS text
          CHECK (
             \"VALUE\" ~ '^\d{5}$'
          OR \"VALUE\" ~ '^\d{5}-\d{4}$'
          );
          """.strip
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
              SELECT * FROM \"users\" WHERE users.id = $1;
          $$ LANGUAGE sql
          """.strip
        end

        it { is_expected.to eq query }
      end

      context 'with or replace' do
        let(:query) do
          """
          CREATE OR REPLACE FUNCTION getfoo(int) RETURNS SETOF users AS $$
              SELECT * FROM \"users\" WHERE users.id = $1;
          $$ LANGUAGE sql
          """.strip
        end

        it { is_expected.to eq query }
      end

      context 'with immutable' do
        let(:query) do
          """
          CREATE OR REPLACE FUNCTION getfoo(int) RETURNS SETOF users AS $$
              SELECT * FROM \"users\" WHERE users.id = $1;
          $$ LANGUAGE sql IMMUTABLE
          """.strip
        end

        it { is_expected.to eq query }
      end

      context 'with STRICT (aka return null on null input)' do
        let(:query) do
          """
          CREATE OR REPLACE FUNCTION getfoo(int) RETURNS SETOF users AS $$
              SELECT * FROM \"users\" WHERE users.id = $1;
          $$ LANGUAGE sql IMMUTABLE RETURNS NULL ON NULL INPUT
          """.strip
        end

        it { is_expected.to eq query }
      end

      context 'with called on null input' do
        let(:query) do
          """
          CREATE OR REPLACE FUNCTION getfoo(int) RETURNS SETOF users AS $$
              SELECT * FROM \"users\" WHERE users.id = $1;
          $$ LANGUAGE sql IMMUTABLE CALLED ON NULL INPUT
          """.strip
        end

        it { is_expected.to eq query }
      end

      context 'without parameters' do
        let(:query) do
          """
          CREATE OR REPLACE FUNCTION getfoo() RETURNS text AS $$
              SELECT name FROM \"users\" LIMIT 1
          $$ LANGUAGE sql IMMUTABLE CALLED ON NULL INPUT
          """.strip
        end

        it { is_expected.to eq query }
      end
    end

    context 'CREATE SCHEMA' do
      # Taken from https://www.postgresql.org/docs/11/sql-createschema.html
      context 'basic' do
        let(:query) { 'CREATE SCHEMA myschema' }

        it { is_expected.to eq query }
      end

      context 'with authorization' do
        let(:query) { 'CREATE SCHEMA AUTHORIZATION joe' }

        it { is_expected.to eq query }
      end

      context 'with if not exist' do
        let(:query) { 'CREATE SCHEMA IF NOT EXISTS test AUTHORIZATION joe' }

        it { is_expected.to eq query }
      end

      context 'with cschema_element' do
        let(:query) do
          """
          CREATE SCHEMA hollywood
          CREATE TABLE films (title text, release date, awards text[])
          CREATE VIEW winners AS
              SELECT title, release FROM films WHERE awards IS NOT NULL
          """.strip
        end

        it { is_expected.to eq oneline_query }
      end
    end

    context 'CREATE TABLE' do
      context 'top-level' do
        let(:query) do
          '''
            CREATE UNLOGGED TABLE cities (
                name            text,
                population      real,
                altitude        double,
                identifier      smallint,
                postal_code     int,
                foreign_id      bigint
           );
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'with common types' do
        let(:query) do
          '''
            CREATE TABLE IF NOT EXISTS distributors (
                name       varchar(40) DEFAULT \'Luso Films\',
                len        interval hour to second(3),
                name       varchar(40) DEFAULT \'Luso Films\',
                did        int DEFAULT nextval(\'distributors_serial\'),
                stamp      timestamp DEFAULT now() NOT NULL,
                stamptz    timestamp with time zone,
                "time"     time NOT NULL,
                timetz     time with time zone,
                CONSTRAINT name_len PRIMARY KEY (name, len)
            );
          '''
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
            'CREATE TABLE types (a real, b double precision, c numeric(2, 3), d char(4), e char(5), f varchar(6), g varchar(7))'
          )
        end
      end

      context 'with custom typecasts with arguments' do
        let(:query) do
          """
            CREATE TABLE types (a geometry(point) not null);
          """
        end

        it do
          is_expected.to eq(
            'CREATE TABLE types (a geometry(point) NOT NULL)'
          )
        end
      end

      context 'with column definition options' do
        let(:query) do
          '''
          CREATE TABLE tablename (
              colname int NOT NULL DEFAULT nextval(\'tablename_colname_seq\')
          );
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'inheriting' do
        let(:query) do
          '''
            CREATE TABLE capitals (
                state           char(2)
            ) INHERITS (cities);
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'temporary table' do
        let(:query) { 'CREATE TEMPORARY TABLE temp AS SELECT c FROM t' }

        it { is_expected.to eq oneline_query }
      end

      context 'create table as' do
        let(:query) { 'CREATE TABLE films2 AS SELECT * FROM films' }

        it { is_expected.to eq oneline_query }
      end

      context 'create table ON COMMIT { PRESERVE ROWS | DELETE ROWS | DROP }' do
        let(:query) { 'CREATE TEMPORARY TABLE films_recent ON COMMIT DROP AS SELECT * FROM films WHERE date_prod > $1' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'DROP GENERAL' do
      context 'server' do
        let(:query) { 'DROP SERVER IF EXISTS foo' }

        it { is_expected.to eq oneline_query }
      end

      context 'PUBLICATION' do
        let(:query) { 'DROP PUBLICATION mypublication' }

        it { is_expected.to eq oneline_query }
      end

      context 'TYPE' do
        let(:query) { 'DROP TYPE box' }

        it { is_expected.to eq oneline_query }
      end

      context 'TABLESPACE' do
        let(:query) { 'DROP TABLESPACE mystuff' }

        it { is_expected.to eq oneline_query }
      end

      context 'CONVERSION' do
        let(:query) { 'DROP CONVERSION myname' }

        it { is_expected.to eq oneline_query }
      end

      context 'SEQUENCE' do
        let(:query) { 'DROP SEQUENCE serial' }

        it { is_expected.to eq oneline_query }
      end

      context 'INDEX' do
        let(:query) { 'DROP INDEX title_idx' }

        it { is_expected.to eq oneline_query }
      end

      context 'MATERIALIZED VIEW' do
        let(:query) { 'DROP MATERIALIZED VIEW order_summary' }

        it { is_expected.to eq oneline_query }
      end

      context 'TRIGGER' do
        let(:query) { 'DROP TRIGGER if_dist_exists ON films' }

        it { is_expected.to eq oneline_query }
      end

      context 'RULE' do
        let(:query) { 'DROP RULE newrule ON mytable' }

        it { is_expected.to eq oneline_query }
      end

      context 'CAST' do
        let(:query) { 'DROP CAST (text AS int)' }

        it { is_expected.to eq oneline_query }
      end

      context 'OPERATOR FAMILY' do
        let(:query) { 'DROP OPERATOR FAMILY float_ops USING btree' }

        it { is_expected.to eq oneline_query }
      end

      context 'AGGREGATE' do
        let(:query) { 'DROP AGGREGATE myavg(int), myavg(bigint)' }

        it { is_expected.to eq oneline_query }
      end

      context 'COLLATION' do
        let(:query) { 'DROP COLLATION german' }

        it { is_expected.to eq oneline_query }
      end

      context 'FOREIGN DATA WRAPPER' do
        let(:query) { 'DROP FOREIGN DATA WRAPPER dbi' }

        it { is_expected.to eq oneline_query }
      end

      context 'ACCESS METHOD' do
        let(:query) { 'DROP ACCESS METHOD heptree' }

        it { is_expected.to eq oneline_query }
      end

      context 'STATISTICS' do
        let(:query) { 'DROP STATISTICS IF EXISTS accounting.users_uid_creation, public.grants_user_role' }

        it { is_expected.to eq oneline_query }
      end

      context 'TEXT SEARCH DICTIONARY' do
        let(:query) { 'DROP TEXT SEARCH DICTIONARY english' }

        it { is_expected.to eq oneline_query }
      end

      context 'OPERATOR CLASS' do
        let(:query) { 'DROP OPERATOR CLASS widget_ops USING btree' }

        it { is_expected.to eq oneline_query }
      end

      context 'POLICY' do
        let(:query) { 'DROP POLICY p1 ON my_table' }

        it { is_expected.to eq oneline_query }
      end

      context 'SUBSCRIPTION' do
        let(:query) { 'DROP SUBSCRIPTION mysub' }

        it { is_expected.to eq oneline_query }
      end

      context 'TEXT SEARCH CONFIGURATION' do
        let(:query) { 'DROP TEXT SEARCH CONFIGURATION my_english' }

        it { is_expected.to eq oneline_query }
      end

      context 'EVENT TRIGGER' do
        let(:query) { 'DROP EVENT TRIGGER snitch' }

        it { is_expected.to eq oneline_query }
      end

      context 'TEXT SEARCH PARSER' do
        let(:query) { 'DROP TEXT SEARCH PARSER my_parser' }

        it { is_expected.to eq oneline_query }
      end

      context 'EXTENSION' do
        let(:query) { 'DROP EXTENSION hstore' }

        it { is_expected.to eq oneline_query }
      end

      context 'DOMAIN' do
        let(:query) { 'DROP DOMAIN box' }

        it { is_expected.to eq oneline_query }
      end

      context 'TEXT SEARCH TEMPLATE' do
        let(:query) { 'DROP TEXT SEARCH TEMPLATE thesaurus' }

        it { is_expected.to eq oneline_query }
      end

      context 'TRANSFORM' do
        let(:query) { 'DROP TRANSFORM FOR hstore LANGUAGE plpythonu' }

        it { is_expected.to eq oneline_query }
      end

      context 'FOREIGN TABLE' do
        let(:query) { 'DROP FOREIGN TABLE films, distributors' }

        it { is_expected.to eq oneline_query }
      end

      context 'FUNCTION with param' do
        let(:query) { 'DROP FUNCTION sqrt(int)' }

        it { is_expected.to eq oneline_query }
      end

      context 'FUNCTION without param' do
        let(:query) { 'DROP FUNCTION update_employee_salaries()' }

        it { is_expected.to eq oneline_query }
      end

      context 'FUNCTION without param and parentheses' do
        let(:query) { 'DROP FUNCTION update_employee_salaries' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'DROP TABLE' do
      context 'cascade' do
        let(:query) { 'DROP TABLE IF EXISTS any_table CASCADE;' }

        it { is_expected.to eq oneline_query }
      end

      context 'restrict' do
        let(:query) { 'DROP TABLE IF EXISTS any_table;' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'DROP SCHEMA' do
      let(:query) { 'DROP SCHEMA IF EXISTS any_schema' }

      it { is_expected.to eq oneline_query }
    end

    context 'ALTER TABLE' do
      context 'with column modifications' do
        let(:query) do
          '''
          ALTER TABLE distributors
            DROP CONSTRAINT distributors_pkey,
            ADD CONSTRAINT distributors_pkey PRIMARY KEY USING INDEX dist_id_temp_idx,
            ADD CONSTRAINT zipchk CHECK (char_length(zipcode) = 5),
            ALTER COLUMN tstamp DROP DEFAULT,
            ALTER COLUMN tstamp TYPE timestamp with time zone
              USING \'epoch\'::timestamp with time zone + (date_part(\'epoch\', tstamp) * \'1 second\'::interval),
            ALTER COLUMN tstamp SET DEFAULT now(),
            ALTER COLUMN tstamp DROP DEFAULT,
            ALTER COLUMN tstamp SET STATISTICS -5,
            ADD COLUMN some_int int NOT NULL,
            DROP IF EXISTS other_column CASCADE;
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'rename' do
        let(:query) { 'ALTER TABLE distributors RENAME TO suppliers' }

        it { is_expected.to eq oneline_query }
      end

      context 'FOREIGN KEY' do
        let(:query) { 'ALTER TABLE distributors ADD CONSTRAINT distfk FOREIGN KEY (address) REFERENCES addresses (address);' }

        it { is_expected.to eq oneline_query }
      end

      context 'FOREIGN KEY NOT VALID' do
        let(:query) { 'ALTER TABLE distributors ADD CONSTRAINT distfk FOREIGN KEY (address) REFERENCES addresses (address) NOT VALID;' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'RENAME' do
      context 'TRIGGER' do
        let(:query) { 'ALTER TRIGGER emp_stamp ON emp RENAME TO emp_track_chgs' }

        it { is_expected.to eq oneline_query }
      end

      context 'CONVERSION' do
        let(:query) { 'ALTER CONVERSION iso_8859_1_to_utf8 RENAME TO latin1_to_unicode' }

        it { is_expected.to eq oneline_query }
      end

      context 'TABLE CONSTRAINT' do
        let(:query) { 'ALTER TABLE distributors RENAME CONSTRAINT zipchk TO zip_check' }

        it { is_expected.to eq oneline_query }
      end

      context 'INDEX' do
        let(:query) { 'ALTER INDEX distributors RENAME TO suppliers' }

        it { is_expected.to eq oneline_query }
      end

      context 'MATERIALIZED VIEW' do
        let(:query) { 'ALTER MATERIALIZED VIEW foo RENAME TO bar' }

        it { is_expected.to eq oneline_query }
      end

      context 'TABLESPACE' do
        let(:query) { 'ALTER TABLESPACE index_space RENAME TO fast_raid' }

        it { is_expected.to eq oneline_query }
      end

      context 'COLUMN' do
        let(:query) { 'ALTER TABLE distributors RENAME COLUMN address TO city' }

        it { is_expected.to eq oneline_query }
      end

      context 'COLLATION' do
        let(:query) { 'ALTER COLLATION "de_DE" RENAME TO german' }

        it { is_expected.to eq oneline_query }
      end

      context 'TYPE' do
        let(:query) { 'ALTER TYPE electronic_mail RENAME TO email' }

        it { is_expected.to eq oneline_query }
      end

      context 'DOMAIN CONSTRAINT' do
        let(:query) { 'ALTER DOMAIN zipcode RENAME CONSTRAINT zipchk TO zip_check' }

        it { is_expected.to eq oneline_query }
      end

      context 'AGGREGATE' do
        let(:query) { 'ALTER AGGREGATE myavg(int) RENAME TO my_average' }

        it { is_expected.to eq oneline_query }
      end

      context 'FUNCTION' do
        let(:query) { 'ALTER FUNCTION sqrt(int) RENAME TO square_root' }

        it { is_expected.to eq oneline_query }
      end

      context 'RULE' do
        let(:query) { 'ALTER RULE notify_all ON emp RENAME TO notify_me' }

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
        let(:query) { 'SAVEPOINT "x y"' }

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

    context 'COMMENTS' do
      let(:query) do
        '''
        CREATE TABLE remove_comments (
          id int -- inline comment in multiline
        );
        '''
      end

      it { is_expected.to eq('CREATE TABLE remove_comments (id int)') }
    end

    context 'OVER' do
      context 'OVER ()' do
        let(:query) { "SELECT rank(*) OVER ()" }

        it { is_expected.to eq query }
      end

      context 'OVER with PARTITION BY' do
        let(:query) { 'SELECT rank(*) OVER (PARTITION BY id)' }

        it { is_expected.to eq query }
      end

      context 'OVER with ORDER BY' do
        let(:query) { 'SELECT rank(*) OVER (ORDER BY id)' }

        it { is_expected.to eq query }
      end

      context 'complex OVER' do
        let(:query) { 'SELECT rank(*) OVER (PARTITION BY id, id2 ORDER BY id DESC, id2)' }

        it { is_expected.to eq query }
      end

      context 'OVER with named window' do
        let(:query) { 'SELECT rank(*) OVER named_window' }

        it { is_expected.to eq query }
      end
    end

    context 'FILTER' do
      context 'FILTER ( WHERE )' do
        let(:query) { 'SELECT max(create_date::date) FILTER (WHERE cancel_date IS NULL) OVER (ORDER BY create_date DESC) FROM tb_x' }

        it { is_expected.to eq query }
      end
    end

    context 'VIEWS' do
      context 'rename view' do
        let(:query) { 'ALTER VIEW foo RENAME TO bar' }

        it { is_expected.to eq query }
      end

      context 'with check option' do
        let(:query) { 'CREATE OR REPLACE TEMPORARY VIEW view_a AS SELECT * FROM a(1) WITH CHECK OPTION' }

        it { is_expected.to eq query }
      end

      context 'drop' do
        let(:query) { 'DROP VIEW kinds' }

        it { is_expected.to eq query }
      end

      context 'recursive' do
        let(:shorthand_query) { 'CREATE RECURSIVE VIEW view_a (a, b) AS SELECT * FROM a(1)' }
        let(:query) { 'CREATE VIEW view_a (a, b) AS WITH RECURSIVE view_a(a, b) AS (SELECT * FROM a(1)) SELECT a, b FROM view_a' }

        it 'parses both and deparses into the normalized form' do
          expect(PgQuery.parse(query).deparse).to eq(query)
          expect(PgQuery.parse(shorthand_query).deparse).to eq(query)
        end
      end
    end

    context 'SET' do
      context 'with integer value' do
        let(:query) do
          '''
          SET statement_timeout TO 10000;
          '''
        end

        it { is_expected.to eq oneline_query }
      end
      context 'with string value' do
        let(:query) do
          '''
          SET search_path TO my_schema, public;
          '''
        end

        it { is_expected.to eq oneline_query }
      end
      context 'with local scope' do
        let(:query) do
          '''
          SET LOCAL search_path TO my_schema, public;
          '''
        end

        it { is_expected.to eq oneline_query }
      end
      # Because SESSION is default, it is removed by the query parser.
      context 'with session scope' do
        let(:query) do
          '''
          SET SESSION search_path TO 10000;
          '''
        end

        it { is_expected.to eq "SET search_path TO 10000" }
      end
    end

    context 'VACUUM' do
      context 'without anything' do
        let(:query) { 'VACUUM' }

        it { is_expected.to eq oneline_query }
      end

      context 'with table name' do
        let(:query) { 'VACUUM t' }

        it { is_expected.to eq oneline_query }
      end

      context 'full' do
        let(:query) { 'VACUUM (FULL) t' }

        it { is_expected.to eq oneline_query }
      end

      context 'freeze' do
        let(:query) { 'VACUUM (FREEZE) t' }

        it { is_expected.to eq oneline_query }
      end

      context 'verbose' do
        let(:query) { 'VACUUM (VERBOSE) t' }

        it { is_expected.to eq oneline_query }
      end

      context 'analyze' do
        let(:query) { 'VACUUM (ANALYZE) t' }

        it { is_expected.to eq oneline_query }
      end

      context 'combine operations' do
        let(:query) { 'VACUUM (FULL, FREEZE, VERBOSE, ANALYZE)' }

        it { is_expected.to eq oneline_query }
      end

      context 'adding column names' do
        let(:query) { 'VACUUM (ANALYZE) t(a, b)' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'LOCK' do
      context 'basic statement' do
        let(:query) { 'LOCK TABLE t' }

        it { is_expected.to eq oneline_query }
      end

      context 'multiple tables' do
        let(:query) { 'LOCK TABLE t, u' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'EXPLAIN' do
      context 'basic statement' do
        let(:query) { 'EXPLAIN SELECT a FROM b' }

        it { is_expected.to eq oneline_query }
      end

      context 'analyze' do
        let(:query) { 'EXPLAIN (ANALYZE) SELECT a FROM b' }

        it { is_expected.to eq oneline_query }
      end

      context 'analyze and buffers' do
        let(:query) { 'EXPLAIN (ANALYZE, BUFFERS) SELECT a FROM b' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'COPY' do
      context 'FROM' do
        let(:query) { 'COPY t FROM STDIN' }

        it { is_expected.to eq oneline_query }
      end

      context 'FROM with columns' do
        let(:query) { 'COPY t(c1, c2) FROM STDIN' }

        it { is_expected.to eq oneline_query }
      end

      context 'FROM program' do
        let(:query) { 'COPY t FROM PROGRAM \'/bin/false\'' }

        it { is_expected.to eq oneline_query }
      end

      context 'FROM filename' do
        let(:query) { 'COPY t FROM \'/dev/null\'' }

        it { is_expected.to eq oneline_query }
      end

      context 'TO' do
        let(:query) { 'COPY t TO STDOUT' }

        it { is_expected.to eq oneline_query }
      end

      context 'SUBQUERY' do
        let(:query) { 'COPY (SELECT 1 FROM foo) TO STDOUT' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'DO' do
      context 'basic statement' do
        let(:query) { 'DO $$BEGIN PERFORM * FROM information_schema.tables; END$$' }

        it { is_expected.to eq oneline_query }
      end

      context 'with language' do
        let(:query) { 'DO $$ BEGIN PERFORM * FROM information_schema.tables; END $$ LANGUAGE plpgsql' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'DISCARD' do
      context 'all' do
        let(:query) { 'DISCARD ALL' }

        it { is_expected.to eq oneline_query }
      end
      context 'plans' do
        let(:query) { 'DISCARD PLANS' }

        it { is_expected.to eq oneline_query }
      end
      context 'sequences' do
        let(:query) { 'DISCARD SEQUENCES' }

        it { is_expected.to eq oneline_query }
      end
      context 'temp' do
        let(:query) { 'DISCARD TEMP' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'DefineStmt' do
      context 'CREATE AGGREGATE' do
        context 'minimal' do
          let(:query) { 'CREATE AGGREGATE aggregate1 (int4) (sfunc = sfunc1, stype = stype1)' }

          it { is_expected.to eq oneline_query }
        end

        context 'multiple arg type' do
          let(:query) { 'CREATE AGGREGATE aggregate1 (int4, bool) (sfunc = sfunc1, stype = stype1)' }

          it { is_expected.to eq oneline_query }
        end

        context 'wildcard arg type' do
          let(:query) { 'CREATE AGGREGATE aggregate1 (*) (sfunc = sfunc1, stype = stype1)' }

          it { is_expected.to eq oneline_query }
        end

        context 'attributes without values' do
          let(:query) { 'CREATE AGGREGATE aggregate1 (int4) (sfunc = sfunc1, stype = stype1, finalfunc_extra, mfinalfuncextra)' }

          it { is_expected.to eq oneline_query }
        end

        context 'attributes with predefined values' do
          let(:query) { 'CREATE AGGREGATE aggregate1 (int4) (sfunc = sfunc1, stype = stype1, finalfunc_modify = read_only, parallel = restricted)' }

          it { is_expected.to eq oneline_query }
        end
      end

      context 'CREATE OPERATOR' do
        context 'minimal' do
          let(:query) { 'CREATE OPERATOR + (procedure = plusfunc)' }

          it { is_expected.to eq oneline_query }
        end

        context 'more arguments' do
          let(:query) { 'CREATE OPERATOR + (procedure = plusfunc, leftarg = int4, rightarg = int4)' }

          it { is_expected.to eq oneline_query }
        end

        context 'empty arguments' do
          let(:query) { 'CREATE OPERATOR + (procedure = plusfunc, hashes, merges)' }

          it { is_expected.to eq oneline_query }
        end
      end

      context 'CREATE TYPE' do
        context 'shell' do
          let(:query) { 'CREATE TYPE type1' }

          it { is_expected.to eq oneline_query }
        end

        context 'composite' do
          let(:query) { 'CREATE TYPE type1 AS (attr1 int4, attr2 bool)' }

          it { is_expected.to eq oneline_query }
        end

        context 'composite with collate' do
          let(:query) { 'CREATE TYPE type1 AS (attr1 int4 COLLATE collation1, attr2 bool)' }

          it { is_expected.to eq oneline_query }
        end

        context 'enum' do
          let(:query) { 'CREATE TYPE type1 AS ENUM (\'value1\', \'value2\', \'value3\')' }

          it { is_expected.to eq oneline_query }
        end

        context 'range' do
          let(:query) { 'CREATE TYPE type1 AS RANGE (subtype = int4)' }

          it { is_expected.to eq oneline_query }
        end

        context 'range with multiple params' do
          let(:query) { 'CREATE TYPE type1 AS RANGE (subtype = int4, receive = receive_func, passedbyvalue)' }

          it { is_expected.to eq oneline_query }
        end

        context 'base' do
          let(:query) { 'CREATE TYPE type1 (input = input1, output = output1)' }

          it { is_expected.to eq oneline_query }
        end

        context 'base with multiple params' do
          let(:query) { 'CREATE TYPE type1 (input = input1, output = output1, passedbyvalue)' }

          it { is_expected.to eq oneline_query }
        end
      end
    end

    context 'GRANT' do
      context 'basic select statement' do
        let(:query) { 'GRANT select ON "table" TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'multiple privileges' do
        let(:query) { 'GRANT select, update, insert ON "table" TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'all tables' do
        let(:query) { 'GRANT select ON ALL TABLES IN SCHEMA schema TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'multiple users' do
        let(:query) { 'GRANT select ON "table" TO user1, user2' }

        it { is_expected.to eq oneline_query }
      end

      context 'user public' do
        let(:query) { 'GRANT select ON "table" TO public' }

        it { is_expected.to eq oneline_query }
      end

      context 'user current user' do
        let(:query) { 'GRANT select ON "table" TO CURRENT_USER' }

        it { is_expected.to eq oneline_query }
      end

      context 'user session user' do
        let(:query) { 'GRANT select ON "table" TO SESSION_USER' }

        it { is_expected.to eq oneline_query }
      end

      context 'all privileges' do
        let(:query) { 'GRANT ALL ON "table" TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'with grant option' do
        let(:query) { 'GRANT select ON "table" TO "user" WITH GRANT OPTION' }

        it { is_expected.to eq oneline_query }
      end

      context 'with column name' do
        let(:query) { 'GRANT select ("column") ON "table" TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'with column names' do
        let(:query) { 'GRANT select (column1, column2) ON "table" TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'sequence' do
        let(:query) { 'GRANT usage ON SEQUENCE sequence TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'all sequences' do
        let(:query) { 'GRANT usage ON ALL SEQUENCES IN SCHEMA schema TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'database' do
        let(:query) { 'GRANT create ON DATABASE database TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'domain' do
        let(:query) { 'GRANT usage ON DOMAIN domain TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'foreign data wrapper' do
        let(:query) { 'GRANT usage ON FOREIGN DATA WRAPPER fdw TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'foreign server' do
        let(:query) { 'GRANT usage ON FOREIGN SERVER server TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'function with unspecified args' do
        let(:query) { 'GRANT execute ON FUNCTION function TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'function without args' do
        let(:query) { 'GRANT execute ON FUNCTION function() TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'function without 1 arg' do
        let(:query) { 'GRANT execute ON FUNCTION function(string) TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'function without multiple args' do
        let(:query) { 'GRANT execute ON FUNCTION function(string, string, boolean) TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'all functions' do
        let(:query) { 'GRANT execute ON ALL FUNCTIONS IN SCHEMA schema TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'language' do
        let(:query) { 'GRANT usage ON LANGUAGE plpgsql TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'large object' do
        let(:query) { 'GRANT select ON LARGE OBJECT 1234 TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'schema' do
        let(:query) { 'GRANT create ON SCHEMA schema TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'tablespace' do
        let(:query) { 'GRANT create ON TABLESPACE tablespace TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'type' do
        let(:query) { 'GRANT usage ON TYPE type TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'role' do
        let(:query) { 'GRANT role TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'multiple roles' do
        let(:query) { 'GRANT role1, role2 TO "user"' }

        it { is_expected.to eq oneline_query }
      end

      context 'with admin option' do
        let(:query) { 'GRANT role TO "user" WITH ADMIN OPTION' }

        it { is_expected.to eq oneline_query }
      end

      context 'drop' do
        let(:query) { 'DROP ROLE jonathan' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'REVOKE' do
      context 'PRIVILEGES' do
        let(:shorthand_query) { 'REVOKE ALL PRIVILEGES ON kinds FROM manuel' }
        let(:query) { 'REVOKE ALL ON kinds FROM manuel' }

        it 'parses both and deparses into the normalized form' do
          expect(PgQuery.parse(query).deparse).to eq(query)
          expect(PgQuery.parse(shorthand_query).deparse).to eq(query)
        end
      end

      context 'role' do
        let(:query) { 'REVOKE admins FROM joe' }

        it { is_expected.to eq oneline_query }
      end

      context 'basic select statement' do
        let(:query) { 'REVOKE insert ON films FROM public' }

        it { is_expected.to eq oneline_query }
      end
    end

    context 'other examples' do
      subject { PgQuery.parse(oneline_query).deparse }

      context 'for single query' do
        let(:query) do
          '''
          SELECT m.name AS mname, pname
            FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'for multiple queries' do
        let(:query) do
          '''
          SELECT m.name AS mname, pname
            FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true;
          INSERT INTO manufacturers_daily (a, b)
            SELECT a, b FROM manufacturers;
          '''
        end

        it { is_expected.to eq oneline_query }
      end

      context 'for multiple queries with a semicolon inside a value' do
        let(:query) do
          '''
          SELECT m.name AS mname, pname
            FROM manufacturers m LEFT JOIN LATERAL get_product_names(m.id) pname ON true;
          UPDATE users SET name = \'bobby; drop tables\';
          INSERT INTO manufacturers_daily (a, b)
            SELECT a, b FROM manufacturers;
          '''
        end

        it { is_expected.to eq oneline_query }
      end
    end

    context 'deep query examples' do
      context 'deparses really deep queries' do
        let(:query) { 'SELECT a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(b))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))' }

        it { is_expected.to eq query }
      end

      context 'deparses really deep queries (2)' do
        let(:query) { 'SELECT * FROM t0 JOIN t1 ON 1 JOIN t2 ON 1 JOIN t3 ON 1 JOIN t4 ON 1 JOIN t5 ON 1 JOIN t6 ON 1 JOIN t7 ON 1 JOIN t8 ON 1 JOIN t9 ON 1 JOIN t10 ON 1 JOIN t11 ON 1 JOIN t12 ON 1 JOIN t13 ON 1 JOIN t14 ON 1 JOIN t15 ON 1 JOIN t16 ON 1 JOIN t17 ON 1 JOIN t18 ON 1 JOIN t19 ON 1 JOIN t20 ON 1 JOIN t21 ON 1 JOIN t22 ON 1 JOIN t23 ON 1 JOIN t24 ON 1 JOIN t25 ON 1 JOIN t26 ON 1 JOIN t27 ON 1 JOIN t28 ON 1 JOIN t29 ON 1' }

        it { is_expected.to eq query }
      end

      context 'deparses really deep queries (3)' do
        let(:query) { 'SELECT * FROM foo ' + (1..100).to_a.map { |i| "JOIN foo_#{i} ON foo.id = foo_#{i}.foo_id" }.join(' ') }

        it { is_expected.to eq query }
      end
    end
  end
end
