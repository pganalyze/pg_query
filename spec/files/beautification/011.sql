SELECT a, b, max(c) FROM t group BY a,b having count(*) > 1 AND min(c) = 2
