-- =====================================================================
-- Q5 - DISTINCT mascarando explosão de JOIN
-- Otimização: reescrita com EXISTS + índices de suporte
-- =====================================================================
--
-- PROBLEMA (antes):
--   O duplo JOIN (leituras → eventos_leitura) produz um produto cartesiano
--   intermediário com dezenas de milhões de linhas. O DISTINCT só elimina
--   os duplicados depois de gerar e ordenar todo esse volume, causando
--   Sort + Unique extremamente caro (~8 s com possível spill para disco).
--
-- HIPÓTESE:
--   Substituir os JOINs por EXISTS transmite a semântica "existe ao menos
--   um registro" ao otimizador, que interrompe a busca na primeira linha
--   válida para cada unidade. Índices em (unidades_id, status) e em
--   (leituras_id, occurred_at) eliminam os Seq Scans nas subtabelas.
-- ---------------------------------------------------------------------

-- Medição ANTES (rode antes de criar os índices):
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT DISTINCT e.id, e.nome, e.segmento
-- FROM energia.unidades e
-- JOIN energia.leituras r ON r.unidades_id = e.id
-- JOIN energia.eventos_leitura ev ON ev.leituras_id = r.id
-- WHERE r.status = 'concluido'
--   AND ev.occurred_at >= NOW() - INTERVAL '30 days';

-- ---------------------------------------------------------------------
-- MUDANÇA 1: índices de suporte para o EXISTS
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_leituras_unidades_status
    ON energia.leituras (unidades_id, status);

CREATE INDEX IF NOT EXISTS idx_eventos_leituras_occurred
    ON energia.eventos_leitura (leituras_id, occurred_at);

ANALYZE energia.leituras;
ANALYZE energia.eventos_leitura;

-- ---------------------------------------------------------------------
-- MUDANÇA 2: consulta reescrita com EXISTS — use esta no lugar da original
-- ---------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT e.id, e.nome, e.segmento
-- FROM energia.unidades e
-- WHERE EXISTS (
--     SELECT 1
--     FROM energia.leituras r
--     JOIN energia.eventos_leitura ev ON ev.leituras_id = r.id
--     WHERE r.unidades_id = e.id
--       AND r.status = 'concluido'
--       AND ev.occurred_at >= NOW() - INTERVAL '30 days'
-- );

-- ---------------------------------------------------------------------
-- ALTERNATIVA TESTADA (semi-join com IN):
--   EXISTS e IN produzem planos equivalentes no PostgreSQL 14+, pois ambos
--   são convertidos internamente para semi-join. Mantivemos EXISTS por ser
--   mais legível e comunicar explicitamente a intenção de "existência".
-- ---------------------------------------------------------------------
-- SELECT e.id, e.nome, e.segmento
-- FROM energia.unidades e
-- WHERE e.id IN (
--     SELECT r.unidades_id
--     FROM energia.leituras r
--     JOIN energia.eventos_leitura ev ON ev.leituras_id = r.id
--     WHERE r.status = 'concluido'
--       AND ev.occurred_at >= NOW() - INTERVAL '30 days'
-- );

-- ---------------------------------------------------------------------
-- Conferir o tamanho dos índices (custo colateral em disco):
-- SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass))
-- FROM pg_indexes
-- WHERE tablename IN ('leituras', 'eventos_leitura')
--   AND schemaname = 'energia'
--   AND indexname IN ('idx_leituras_unidades_status', 'idx_eventos_leituras_occurred');
--
-- Para desfazer:
-- DROP INDEX energia.idx_leituras_unidades_status;
-- DROP INDEX energia.idx_eventos_leituras_occurred;
-- =====================================================================
