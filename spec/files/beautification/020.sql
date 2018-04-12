with x as (Select relkind, count(*) FROM pg_class group BY 1),
y as (Select count(*) FROM pg_Database)
SELECT count(*) FROM x, y;
