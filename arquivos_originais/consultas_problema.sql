-- Consultas-problema do estudo de caso A2: Energia IoT.
-- Execute EXPLAIN (ANALYZE, BUFFERS), registre antes/depois e teste uma
-- mudanca por vez. O objetivo e tornar a diferenca de otimizacao visivel.

SELECT pg_stat_statements_reset();

-- Q1 - Painel operacional recente.
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.equipe, r.status, r.prioridade, r.titulo, r.occurred_at
FROM energia.leituras r
JOIN energia.tecnicos a ON a.id = r.tecnicos_id
WHERE r.status IN ('aberto', 'em_andamento')
  AND r.occurred_at >= NOW() - INTERVAL '90 days'
ORDER BY r.prioridade DESC, r.occurred_at ASC
LIMIT 250;

-- Q2 - Busca por e-mail digitado com variacao de maiusculas/minusculas.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nome, email, cidade, segmento
FROM energia.unidades
WHERE UPPER(email) = UPPER('contato410@empresa410.com.br');

-- Q3 - Filtro em JSONB.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, titulo, tags, occurred_at
FROM energia.leituras
WHERE tags @> '{"produto":"app-mobile"}'
ORDER BY occurred_at DESC
LIMIT 80;

-- Q4 - Predicado nao sargable em data.
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM energia.leituras
WHERE DATE(occurred_at) = DATE '2026-05-09';

-- Q5 - DISTINCT mascarando explosao de JOIN.
EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT e.id, e.nome, e.segmento
FROM energia.unidades e
JOIN energia.leituras r ON r.unidades_id = e.id
JOIN energia.eventos_leitura ev ON ev.leituras_id = r.id
WHERE r.status = 'concluido'
  AND ev.occurred_at >= NOW() - INTERVAL '30 days';

-- Q6 - Subconsulta correlacionada sobre tabela de eventos.
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.id, r.titulo, r.occurred_at,
       (SELECT COUNT(*) FROM energia.eventos_leitura ev WHERE ev.leituras_id = r.id) AS qt_eventos
FROM energia.leituras r
WHERE r.status = 'aberto'
ORDER BY r.occurred_at DESC
LIMIT 120;

-- Q7 - Busca textual com curinga a esquerda.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, titulo, occurred_at
FROM energia.leituras
WHERE descricao LIKE '%pagamento%recusado%'
LIMIT 80;

-- Q8 - Dashboard gerencial com risco de spill em work_mem padrao.
EXPLAIN (ANALYZE, BUFFERS)
SELECT tecnicos_id, unidades_id, status, COUNT(*) AS total,
       SUM(valor) AS valor_total,
       MAX(occurred_at) AS ultimo,
       MIN(occurred_at) AS primeiro
FROM energia.leituras
GROUP BY tecnicos_id, unidades_id, status
ORDER BY total DESC, valor_total DESC;

-- Q9 - Serie temporal em tabela com milhoes de eventos.
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE_TRUNC('day', occurred_at) AS dia, COUNT(*) AS total
FROM energia.eventos_leitura
WHERE occurred_at >= TIMESTAMP '2026-04-01'
GROUP BY 1
ORDER BY 1;

-- Apoio para priorizacao por custo agregado.
SELECT calls, round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS media_ms,
       rows, left(query, 120) AS consulta
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 12;
