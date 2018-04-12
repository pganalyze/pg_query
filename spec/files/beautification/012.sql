SELECT CASE relkind WHEN 'r' THEN 'TABLE' when 'i' THEN 'INDEX' ELSE 'STH-ELSE' END as type FROM pg_class
