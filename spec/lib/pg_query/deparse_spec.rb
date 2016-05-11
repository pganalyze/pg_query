require 'spec_helper'

describe PgQuery::Deparse do
  let(:oneline_query) { query.gsub(/\s+/, ' ').gsub('( ', '(').gsub(' )', ')').strip.chomp(';') }
  let(:parsetree) { PgQuery.parse(query).tree }

  describe '.from' do
    subject { described_class.from(parsetree.first) }

    context 'SELECT' do
      context 'basic statement' do
        let(:query) { 'SELECT "a" AS b FROM "x" WHERE "y" = 5 AND "z" = "y"' }
        it { is_expected.to eq query }
      end

      context 'complex SELECT statement' do
        let(:query) { 'SELECT "memory_total_bytes", "memory_swap_total_bytes" - "memory_swap_free_bytes" AS swap, date_part(?, "s"."collected_at") AS collected_at FROM "snapshots" s JOIN "system_snapshots" ON "snapshot_id" = "s"."id" WHERE "s"."database_id" = ? AND "s"."collected_at" >= ? AND "s"."collected_at" <= ? ORDER BY "collected_at" ASC' }
        it { is_expected.to eq query }
      end

      context 'with specific column alias' do
        let(:query) { "SELECT * FROM (VALUES ('anne', 'smith'), ('bob', 'jones'), ('joe', 'blow')) names(\"first\", \"last\")" }
        it { is_expected.to eq oneline_query }
      end

      context 'simple WITH statement' do
        let(:query) { 'WITH t AS (SELECT random() AS x FROM generate_series(1, 3)) SELECT * FROM "t"' }
        it { is_expected.to eq query }
      end

      context 'complex WITH statement' do
        # Taken from http://www.postgresql.org/docs/9.1/static/queries-with.html
        let(:query) do
          %(
          WITH RECURSIVE search_graph ("id", "link", "data", "depth", "path", "cycle") AS (
              SELECT "g"."id", "g"."link", "g"."data", 1,
                ARRAY[ROW("g"."f1", "g"."f2")],
                false
              FROM "graph" g
            UNION ALL
              SELECT "g"."id", "g"."link", "g"."data", "sg"."depth" + 1,
                "path" || ROW("g"."f1", "g"."f2"),
                ROW("g"."f1", "g"."f2") = ANY("path")
              FROM "graph" g, "search_graph" sg
              WHERE "g"."id" = "sg"."link" AND NOT "cycle"
          )
          SELECT "id", "data", "link" FROM "search_graph";
          )
        end
        it { is_expected.to eq oneline_query }
      end

      context 'SUM' do
        let(:query) { 'SELECT sum("price_cents") FROM "products"' }
        it { is_expected.to eq query }
      end

      context 'LATERAL' do
        let(:query) { 'SELECT "m"."name" AS mname, "pname" FROM "manufacturers" m, LATERAL get_product_names("m"."id") pname' }
        it { is_expected.to eq query }
      end

      context 'LATERAL JOIN' do
        let(:query) do
          %(
          SELECT "m"."name" AS mname, "pname"
            FROM "manufacturers" m LEFT JOIN LATERAL get_product_names("m"."id") pname ON true
          )
        end
        it { is_expected.to eq oneline_query }
      end

      context 'CROSS JOIN' do
        let(:query) do
          'SELECT "x", "y" FROM "a" CROSS JOIN "b"'
        end
        it { is_expected.to eq query }
      end

      context 'omitted FROM clause' do
        let(:query) { 'SELECT 2 + 2' }
        it { is_expected.to eq query }
      end

      context 'IS NULL' do
        let(:query) { 'SELECT * FROM "x" WHERE "y" IS NULL' }
        it { is_expected.to eq query }
      end

      context 'IS NOT NULL' do
        let(:query) { 'SELECT * FROM "x" WHERE "y" IS NOT NULL' }
        it { is_expected.to eq query }
      end

      context 'COUNT' do
        let(:query) { 'SELECT count(*) FROM "x" WHERE "y" IS NOT NULL' }
        it { is_expected.to eq query }
      end

      context 'COUNT DISTINCT' do
        let(:query) { 'SELECT count(DISTINCT "a") FROM "x" WHERE "y" IS NOT NULL' }
        it { is_expected.to eq query }
      end

      context 'basic CASE WHEN statements' do
        let(:query) { 'SELECT CASE WHEN "a"."status" = 1 THEN \'active\' WHEN "a"."status" = 2 THEN \'inactive\' END FROM "accounts" a' }
        it { is_expected.to eq query }
      end

      context 'CASE WHEN statements with ELSE clause' do
        let(:query) { 'SELECT CASE WHEN "a"."status" = 1 THEN \'active\' WHEN "a"."status" = 2 THEN \'inactive\' ELSE \'unknown\' END FROM "accounts" a' }
        it { is_expected.to eq query }
      end

      context 'CASE WHEN statements in WHERE clause' do
        let(:query) { 'SELECT * FROM "accounts" WHERE "status" = CASE WHEN "x" = 1 THEN \'active\' ELSE \'inactive\' END' }
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
        let(:query) { 'SELECT * FROM "x" WHERE "id" IN (1, 2, 3)' }
        it { is_expected.to eq query }
      end

      context 'IN expression Subselect' do
        let(:query) { 'SELECT * FROM "x" WHERE "id" IN (SELECT "id" FROM "account")' }
        it { is_expected.to eq query }
      end

      context 'NOT IN expression' do
        let(:query) { 'SELECT * FROM "x" WHERE "id" NOT IN (1, 2, 3)' }
        it { is_expected.to eq query }
      end

      context 'Subselect JOIN' do
        let(:query) { 'SELECT * FROM "x" JOIN (SELECT "n" FROM "z") b ON "a"."id" = "b"."id"' }
        it { is_expected.to eq query }
      end

      context 'simple indirection' do
        let(:query) { 'SELECT * FROM "x" WHERE "y" = "z"[?]' }
        it { is_expected.to eq query }
      end

      context 'complex indirection' do
        let(:query) { 'SELECT * FROM "x" WHERE "y" = "z"[?][?]' }
        it { is_expected.to eq query }
      end

      context 'NOT' do
        let(:query) { 'SELECT * FROM "x" WHERE NOT "y"' }
        it { is_expected.to eq query }
      end

      context 'OR' do
        let(:query) { 'SELECT * FROM "x" WHERE "x" OR "y"' }
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

      context 'ANY' do
        let(:query) { 'SELECT * FROM "x" WHERE "x" = ANY(?)' }
        it { is_expected.to eq query }
      end

      context 'COALESCE' do
        let(:query) { 'SELECT * FROM "x" WHERE "x" = COALESCE("y", ?)' }
        it { is_expected.to eq query }
      end

      context 'GROUP BY' do
        let(:query) { 'SELECT "a", "b", max("c") FROM "c" WHERE "d" = 1 GROUP BY "a", "b"' }
        it { is_expected.to eq query }
      end

      context 'LIMIT' do
        let(:query) { 'SELECT * FROM "x" LIMIT 50' }
        it { is_expected.to eq query }
      end

      context 'OFFSET' do
        let(:query) { 'SELECT * FROM "x" OFFSET 50' }
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
        let(:query) { 'INSERT INTO "x" (y, z) VALUES (1, \'abc\')' }
        it { is_expected.to eq query }
      end

      context 'INTO SELECT' do
        let(:query) { 'INSERT INTO "x" SELECT * FROM "y"' }
        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          '''
          WITH moved AS (
            DELETE
            FROM "employees"
            WHERE "manager_name" = \'Mary\'
          )
          INSERT INTO "employees_of_mary"
          SELECT * FROM "moved";
          '''
        end
        it { is_expected.to eq oneline_query }
      end

      context 'HAVING' do
        let(:query) do
          '''
          INSERT INTO "employees"
          SELECT * FROM "people"
          WHERE 1 = 1
          GROUP BY "name"
          HAVING count("name") > 1
          ORDER BY "name" DESC
          LIMIT 10
          OFFSET 15
          FOR UPDATE
          '''
        end
        it { is_expected.to eq oneline_query }
      end

      context 'with locks' do
        let(:query) do
          '''
          SELECT * FROM "people" FOR UPDATE OF "name", "email"
          '''
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'UPDATE' do
      context 'basic' do
        let(:query) { 'UPDATE "x" SET y = 1 WHERE "z" = \'abc\'' }
        it { is_expected.to eq query }
      end

      context 'elaborate' do
        let(:query) do
          'UPDATE ONLY "x" table_x SET y = 1 WHERE "z" = \'abc\' RETURNING "y" AS changed_y'
        end
        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          '''
          WITH archived AS (
            DELETE
            FROM "employees"
            WHERE "manager_name" = \'Mary\'
          )
          UPDATE "users" SET archived = true WHERE "users"."id" IN (SELECT "user_id" FROM "moved")
          '''
        end
        it { is_expected.to eq oneline_query }
      end

      context 'from generated sequence' do
        let(:query) do
          '''
            INSERT INTO "jackdanger_card_totals" (id, amount_cents, created_at)
            SELECT
              "series"."i",
              random() * 1000,
              (SELECT
                 \'2015-08-25 00:00:00 -0700\'::timestamp +
                ((\'2015-08-25 23:59:59 -0700\'::timestamp - \'2015-08-25 00:00:00 -0700\'::timestamp) * random()))
              FROM generate_series(1, 10000) series("i");
          '''
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'DELETE' do
      context 'basic' do
        let(:query) { 'DELETE FROM "x" WHERE "y" = 1' }
        it { is_expected.to eq query }
      end

      context 'elaborate' do
        let(:query) { 'DELETE FROM ONLY "x" table_x USING "table_z" WHERE "y" = 1 RETURNING *' }
        it { is_expected.to eq query }
      end

      context 'WITH' do
        let(:query) do
          '''
          WITH archived AS (
            DELETE
            FROM "employees"
            WHERE "manager_name" = \'Mary\'
          )
          DELETE FROM "users" WHERE "users"."id" IN (SELECT "user_id" FROM "moved")
          '''
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'CREATE FUNCTION' do
      # Taken from http://www.postgresql.org/docs/8.3/static/queries-table-expressions.html
      context 'with inline function definition' do
        let(:query) do
          """
          CREATE FUNCTION \"getfoo\"(int) RETURNS SETOF users AS $$
              SELECT * FROM \"users\" WHERE users.id = $1;
          $$ language \"sql\"
          """.strip
        end
        it { is_expected.to eq query }
      end
    end

    context 'CREATE TABLE' do
      context 'top-level' do
        let(:query) do
          '''
            CREATE UNLOGGED TABLE "cities" (
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
            CREATE TABLE IF NOT EXISTS "distributors" (
                name       varchar(40) DEFAULT \'Luso Films\',
                len        interval hour to second(3),
                name       varchar(40) DEFAULT \'Luso Films\',
                did        int DEFAULT nextval(\'distributors_serial\'),
                stamp      timestamp DEFAULT now() NOT NULL,
                stamptz    timestamp with time zone,
                time       time NOT NULL,
                timetz     time with time zone,
                CONSTRAINT name_len PRIMARY KEY ("name", "len")
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
            'CREATE TABLE "types" (a real, b double, c numeric(2, 3), d char(4), e char(5), f varchar(6), g varchar(7))'
          )
        end
      end

      context 'with column definition options' do
        let(:query) do
          '''
          CREATE TABLE "tablename" (
              colname int NOT NULL DEFAULT nextval(\'tablename_colname_seq\')
          );
          '''
        end
        it { is_expected.to eq oneline_query }
      end

      context 'inheriting' do
        let(:query) do
          '''
            CREATE TABLE "capitals" (
                state           char(2)
            ) INHERITS ("cities");
          '''
        end
        it { is_expected.to eq oneline_query }
      end
    end

    context 'DROP TABLE' do
      context 'cascade' do
        let(:query) { 'DROP TABLE IF EXISTS "any_table" CASCADE;' }
        it { is_expected.to eq oneline_query }
      end

      context 'restrict' do
        let(:query) { 'DROP TABLE IF EXISTS "any_table";' }
        it { is_expected.to eq oneline_query }
      end
    end

    context 'ALTER TABLE' do
      context 'with column modifications' do
        let(:query) do
          '''
          ALTER TABLE "distributors"
            DROP CONSTRAINT distributors_pkey,
            ADD CONSTRAINT distributors_pkey PRIMARY KEY USING INDEX dist_id_temp_idx,
            ADD CONSTRAINT zipchk CHECK (char_length("zipcode") = 5),
            ALTER COLUMN tstamp DROP DEFAULT,
            ALTER COLUMN tstamp TYPE timestamp with time zone
              USING \'epoch\'::timestamp with time zone + (date_part(\'epoch\', "tstamp") * \'1 second\'::interval),
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
        let(:query) { 'ALTER TABLE "distributors" RENAME TO suppliers;' }
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
        let(:query) { 'SAVEPOINT "x"' }
        it { is_expected.to eq query }
      end

      context 'ROLLBACK TO SAFEPOINT' do
        let(:query) { 'ROLLBACK TO SAVEPOINT "x"' }
        it { is_expected.to eq query }
      end

      context 'RELEASE' do
        let(:query) { 'RELEASE "x"' }
        it { is_expected.to eq query }
      end
    end

    context 'COMMENTS' do
      let(:query) do
        '''
        CREATE TABLE "remove_comments" (
          id int -- inline comment in multiline
        );
        '''
      end
      it { is_expected.to eq('CREATE TABLE "remove_comments" (id int)') }
    end

    context 'OVER' do
      context 'OVER ()' do
        let(:query) { "SELECT rank(*) OVER ()" }
        it { is_expected.to eq query }
      end

      context 'OVER with PARTITION BY' do
        let(:query) { 'SELECT rank(*) OVER (PARTITION BY "id")' }
        it { is_expected.to eq query }
      end

      context 'OVER with ORDER BY' do
        let(:query) { 'SELECT rank(*) OVER (ORDER BY "id")' }
        it { is_expected.to eq query }
      end

      context 'complex OVER' do
        let(:query) { 'SELECT rank(*) OVER (PARTITION BY "id", "id2" ORDER BY "id" DESC, "id2")' }
        it { is_expected.to eq query }
      end
    end

    context 'VIEWS' do
      context 'with check option' do
        let(:query) { 'CREATE OR REPLACE TEMPORARY VIEW view_a AS SELECT * FROM a(1) WITH CASCADED CHECK OPTION' }
        it { is_expected.to eq query }
      end

      context 'recursive' do
        let(:shorthand_query) { 'CREATE RECURSIVE VIEW view_a (a, b) AS SELECT * FROM a(1)' }
        let(:query) { 'CREATE VIEW view_a ("a", "b") AS WITH RECURSIVE view_a ("a", "b") AS (SELECT * FROM a(1)) SELECT "a", "b" FROM "view_a"' }

        it 'parses both and deparses into the normalized form' do
          expect(described_class.from(PgQuery.parse(query).tree.first)).to eq(query)
          expect(described_class.from(PgQuery.parse(shorthand_query).tree.first)).to eq(query)
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
          SET search_path TO \'my_schema\', \'public\';
          '''
        end
        it { is_expected.to eq oneline_query }
      end
      context 'with local scope' do
        let(:query) do
          '''
          SET LOCAL search_path TO \'my_schema\', \'public\';
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
  end

  describe '#deparse' do
    subject { PgQuery.parse(oneline_query).deparse }

    context 'for single query' do
      let(:query) do
        '''
        SELECT "m"."name" AS mname, "pname"
          FROM "manufacturers" m LEFT JOIN LATERAL get_product_names("m"."id") pname ON true
        '''
      end
      it { is_expected.to eq oneline_query }
    end

    context 'for multiple queries' do
      let(:query) do
        '''
        SELECT "m"."name" AS mname, "pname"
          FROM "manufacturers" m LEFT JOIN LATERAL get_product_names("m"."id") pname ON true;
        INSERT INTO "manufacturers_daily" (a, b)
          SELECT "a", "b" FROM "manufacturers";
        '''
      end
      it { is_expected.to eq oneline_query }
    end

    context 'for multiple queries with a semicolon inside a value' do
      let(:query) do
        '''
        SELECT "m"."name" AS mname, "pname"
          FROM "manufacturers" m LEFT JOIN LATERAL get_product_names("m"."id") pname ON true;
        UPDATE "users" SET name = \'bobby; drop tables\';
        INSERT INTO "manufacturers_daily" (a, b)
          SELECT "a", "b" FROM "manufacturers";
        '''
      end
      it { is_expected.to eq oneline_query }
    end
  end

  describe PgQuery::Deparse::Interval do
    describe '.from_int' do
      it 'unpacks the parts of the interval' do
        # Supported combinations taken directly from gram.y
        {
          # the SQL form    => what PG stores
          %w(year)          => %w(YEAR),
          %w(month)         => %w(MONTH),
          %w(day)           => %w(DAY),
          %w(hour)          => %w(HOUR),
          %w(minute)        => %w(MINUTE),
          %w(second)        => %w(SECOND),
          %w(year month)    => %w(YEAR MONTH),
          %w(day hour)      => %w(DAY HOUR),
          %w(day minute)    => %w(DAY HOUR MINUTE),
          %w(day second)    => %w(DAY HOUR MINUTE SECOND),
          %w(hour minute)   => %w(HOUR MINUTE),
          %w(hour second)   => %w(HOUR MINUTE SECOND),
          %w(minute second) => %w(MINUTE SECOND)
        }.each do |sql_parts, storage_parts|
          number = storage_parts.reduce(0) do |num, part|
            num | (1 << described_class::KEYS[part])
          end
          expect(described_class.from_int(number).sort).to eq(sql_parts.sort)
        end
      end
    end
  end
end
