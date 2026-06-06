-- =====================================================================
-- Q3 - Filtro em JSONB
-- Otimização: índice GIN sobre a coluna tags
-- =====================================================================
--
-- PROBLEMA (antes):
--   A consulta usa o operador @> (contenção JSONB) para filtrar leituras
--   por produto. Sem índice em tags, o banco desserializa e compara cada
--   linha individualmente: Seq Scan em 250 mil linhas, ~245 ms.
--
-- HIPÓTESE:
--   O tipo GIN indexa cada chave/valor do documento JSONB separadamente.
--   Com um GIN em tags, o operador @> localiza diretamente as linhas
--   que contêm o par pesquisado, sem varrer a tabela.
-- ---------------------------------------------------------------------

-- Medição ANTES (rode antes de criar o índice):
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT id, titulo, tags, occurred_at
-- FROM energia.leituras
-- WHERE tags @> '{"produto":"app-mobile"}'
-- ORDER BY occurred_at DESC
-- LIMIT 80;

-- ---------------------------------------------------------------------
-- MUDANÇA APLICADA: índice GIN sobre tags
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_leituras_tags_gin
    ON energia.leituras USING GIN (tags);

-- Atualiza as estatísticas para o otimizador considerar o novo índice.
ANALYZE energia.leituras;

-- Medição DEPOIS: rode novamente o mesmo EXPLAIN (ANALYZE, BUFFERS) acima.

-- ---------------------------------------------------------------------
-- ALTERNATIVA TESTADA (GIN com jsonb_path_ops):
--   O operador de classe jsonb_path_ops produz um índice menor e mais
--   rápido para @>, mas só suporta esse operador. Como podem surgir
--   consultas com ? ou ?|, mantivemos o operador padrão para maior
--   compatibilidade.
-- ---------------------------------------------------------------------
-- CREATE INDEX idx_leituras_tags_gin_pathops
--     ON energia.leituras USING GIN (tags jsonb_path_ops);

-- ---------------------------------------------------------------------
-- Conferir o tamanho do índice (custo colateral em disco):
-- SELECT pg_size_pretty(pg_relation_size('energia.idx_leituras_tags_gin'));
--
-- Para desfazer:
-- DROP INDEX energia.idx_leituras_tags_gin;
-- =====================================================================
