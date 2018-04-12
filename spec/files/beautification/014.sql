SELECT x FROM a join x on a.y = x.y join b ON a.c = b."id" AND a.d = b.d AND ( ( a.e >= 123 AND a.e <= 234) OR ( a.f = 'x' AND a.g <= 500))
