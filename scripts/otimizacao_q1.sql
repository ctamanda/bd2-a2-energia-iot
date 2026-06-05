-- =====================================================================
-- Q1 - Painel operacional recente
-- Otimização: índice composto para o filtro de status + data
-- =====================================================================
--
-- PROBLEMA (antes):
--   A consulta filtra energia.leituras por status e occurred_at, mas não
--   existe índice nessas colunas. O PostgreSQL faz um Seq Scan na tabela
--   inteira (250 mil linhas) e descarta a maioria pelo filtro.
--
-- HIPÓTESE:
--   Um índice composto em (status, occurred_at) permite que o banco
--   localize diretamente as linhas dos status pesquisados dentro da
--   janela de data, trocando o Seq Scan por um Bitmap/Index Scan.
-- ---------------------------------------------------------------------

-- Medição ANTES (rode antes de criar o índice):
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT a.equipe, r.status, r.prioridade, r.titulo, r.occurred_at
-- FROM energia.leituras r
-- JOIN energia.tecnicos a ON a.id = r.tecnicos_id
-- WHERE r.status IN ('aberto', 'em_andamento')
--   AND r.occurred_at >= NOW() - INTERVAL '90 days'
-- ORDER BY r.prioridade DESC, r.occurred_at ASC
-- LIMIT 250;

-- ---------------------------------------------------------------------
-- MUDANÇA APLICADA: índice composto (status, occurred_at)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_leituras_status_occurred
    ON energia.leituras (status, occurred_at);

-- Atualiza as estatísticas para o otimizador considerar o novo índice.
ANALYZE energia.leituras;

-- Medição DEPOIS: rode novamente o mesmo EXPLAIN (ANALYZE, BUFFERS) acima.

-- ---------------------------------------------------------------------
-- ALTERNATIVA TESTADA (índice parcial, mais enxuto):
--   Como o painel só consulta dois status, um índice parcial cobre o
--   mesmo caso ocupando menos espaço. Mantivemos o índice composto por
--   ser mais reutilizável por outras consultas operacionais.
-- ---------------------------------------------------------------------
-- CREATE INDEX idx_leituras_status_occurred_parcial
--     ON energia.leituras (occurred_at)
--     WHERE status IN ('aberto', 'em_andamento');

-- ---------------------------------------------------------------------
-- Conferir o tamanho do índice (custo colateral em disco):
-- SELECT pg_size_pretty(pg_relation_size('energia.idx_leituras_status_occurred'));
--
-- Para desfazer:
-- DROP INDEX energia.idx_leituras_status_occurred;
-- =====================================================================
