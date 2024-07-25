CREATE TABLE eager_agg_t1 (a int, b int, c double precision);
CREATE TABLE eager_agg_t2 (a int, b int, c double precision);
INSERT INTO eager_agg_t1 SELECT i, i, i FROM generate_series(1, 1000)i;
INSERT INTO eager_agg_t2 SELECT i, i%10, i FROM generate_series(1, 1000)i;
ANALYZE eager_agg_t1;
ANALYZE eager_agg_t2;

postgres=# explain(verbose) SELECT t1.a, avg(t2.c) FROM eager_agg_t1 t1 JOIN eager_agg_t2 t2 ON t1.b = t2.b GROUP BY t1.a;
                                         QUERY PLAN                                         
--------------------------------------------------------------------------------------------
 HashAggregate  (cost=63.25..75.75 rows=1000 width=12)
   Output: t1.a, avg(t2.c)
   Group Key: t1.a
   ->  Hash Join  (cost=28.50..58.25 rows=1000 width=12)
         Output: t1.a, t2.c
         Hash Cond: (t2.b = t1.b)
         ->  Seq Scan on public.eager_agg_t2 t2  (cost=0.00..16.00 rows=1000 width=12)
               Output: t2.a, t2.b, t2.c
         ->  Hash  (cost=16.00..16.00 rows=1000 width=8)
               Output: t1.a, t1.b
               ->  Seq Scan on public.eager_agg_t1 t1  (cost=0.00..16.00 rows=1000 width=8)
                     Output: t1.a, t1.b
(12 rows)

postgres=# set enable_eager_aggregate = on;
SET
postgres=# explain(verbose) SELECT t1.a, avg(t2.c) FROM eager_agg_t1 t1 JOIN eager_agg_t2 t2 ON t1.b = t2.b GROUP BY t1.a;
                                               QUERY PLAN                                                
---------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=41.24..41.44 rows=10 width=12)
   Output: t1.a, avg(t2.c)
   Group Key: t1.a
   ->  Sort  (cost=41.24..41.27 rows=10 width=36)
         Output: t1.a, (PARTIAL avg(t2.c))
         Sort Key: t1.a
         ->  Hash Join  (cost=21.23..41.08 rows=10 width=36)
               Output: t1.a, (PARTIAL avg(t2.c))
               Hash Cond: (t1.b = t2.b)
               ->  Seq Scan on public.eager_agg_t1 t1  (cost=0.00..16.00 rows=1000 width=8)
                     Output: t1.a, t1.b, t1.c
               ->  Hash  (cost=21.10..21.10 rows=10 width=36)
                     Output: t2.b, (PARTIAL avg(t2.c))
                     ->  Partial HashAggregate  (cost=21.00..21.10 rows=10 width=36)
                           Output: t2.b, PARTIAL avg(t2.c)
                           Group Key: t2.b
                           ->  Seq Scan on public.eager_agg_t2 t2  (cost=0.00..16.00 rows=1000 width=12)
                                 Output: t2.a, t2.b, t2.c
(18 rows)

