-- =====================================================================
-- Q4 - Predicado não-sargable em data
-- Otimização: reescrita do filtro como faixa + índice em occurred_at
-- =====================================================================
--
-- PROBLEMA (antes):
--   DATE(occurred_at) = DATE '2026-05-09' envolve a coluna em uma função,
--   tornando o predicado não-sargable. O banco não pode usar nenhum índice
--   em occurred_at e faz Seq Scan nas 250 mil linhas (~187 ms).
--
-- HIPÓTESE:
--   Reescrever como faixa explícita de timestamps deixa a coluna "nua"
--   no WHERE, tornando o predicado sargable. Com um índice B-tree em
--   occurred_at, o banco faz Bitmap Index Scan diretamente no intervalo.
-- ---------------------------------------------------------------------

-- Medição ANTES (rode com a query original, ANTES de criar o índice):
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT COUNT(*)
-- FROM energia.leituras
-- WHERE DATE(occurred_at) = DATE '2026-05-09';

-- ---------------------------------------------------------------------
-- MUDANÇA 1: índice B-tree em occurred_at
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_leituras_occurred
    ON energia.leituras (occurred_at);

-- Atualiza as estatísticas para o otimizador considerar o novo índice.
ANALYZE energia.leituras;

-- ---------------------------------------------------------------------
-- MUDANÇA 2: consulta reescrita — use esta no lugar da original
-- ---------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT COUNT(*)
-- FROM energia.leituras
-- WHERE occurred_at >= '2026-05-09 00:00:00'
--   AND occurred_at < '2026-05-10 00:00:00';

-- ---------------------------------------------------------------------
-- VERIFICAÇÃO: rode a consulta original com o índice já criado — o banco
-- AINDA NÃO o usa enquanto DATE() envolver a coluna (confirma o diagnóstico).
-- Depois rode a reescrita para ver o Bitmap Index Scan.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- ALTERNATIVA TESTADA (índice de expressão sobre DATE(occurred_at)):
--   Criar um índice de expressão em DATE(occurred_at) também tornaria o
--   predicado original sargable, sem precisar reescrever a consulta. Porém
--   esse índice só serve para igualdades de data exata; a faixa de timestamps
--   é mais genérica e reutilizável para intervalos arbitrários.
-- ---------------------------------------------------------------------
-- CREATE INDEX idx_leituras_date_occurred
--     ON energia.leituras (DATE(occurred_at));

-- ---------------------------------------------------------------------
-- Conferir o tamanho do índice (custo colateral em disco):
-- SELECT pg_size_pretty(pg_relation_size('energia.idx_leituras_occurred'));
--
-- Para desfazer:
-- DROP INDEX energia.idx_leituras_occurred;
-- =====================================================================
