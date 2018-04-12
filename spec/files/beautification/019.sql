with recursive x as (Select relkind, count(*) FROM pg_class group BY 1) SELECT count(*) FROM x;
