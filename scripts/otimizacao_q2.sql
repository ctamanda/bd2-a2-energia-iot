-- =====================================================================
-- Q2 - Busca por e-mail ignorando maiúsculas/minúsculas
-- Otimização: índice de expressão sobre UPPER(email)
-- =====================================================================
--
-- PROBLEMA (antes):
--   A coluna email já possui um índice UNIQUE, mas a consulta usa
--   UPPER(email) = UPPER('...'). Aplicar uma função na coluna torna o
--   predicado NÃO-SARGABLE: o índice comum em email não pode ser usado,
--   e o banco cai em Seq Scan (50 mil linhas) para achar 1 registro.
--
-- HIPÓTESE:
--   Um índice de EXPRESSÃO sobre UPPER(email) armazena exatamente o
--   valor que aparece no WHERE. Assim o otimizador consegue um Index
--   Scan direto, sem varrer a tabela.
-- ---------------------------------------------------------------------

-- Medição ANTES (rode antes de criar o índice):
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT id, nome, email, cidade, segmento
-- FROM energia.unidades
-- WHERE UPPER(email) = UPPER('contato410@empresa410.com.br');

-- ---------------------------------------------------------------------
-- MUDANÇA APLICADA: índice de expressão UPPER(email)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_unidades_upper_email
    ON energia.unidades (UPPER(email));

-- Atualiza as estatísticas para o otimizador considerar o novo índice.
ANALYZE energia.unidades;

-- Medição DEPOIS: rode novamente o mesmo EXPLAIN (ANALYZE, BUFFERS) acima.

-- ---------------------------------------------------------------------
-- ALTERNATIVA TESTADA (reescrita sem função na coluna):
--   Bastaria comparar email diretamente, mas isso muda a semântica
--   (passaria a diferenciar maiúsculas/minúsculas). Para manter a busca
--   case-insensitive, o índice de expressão é a solução correta.
--   Outra opção seria o tipo CITEXT, que exige alterar o schema.
-- ---------------------------------------------------------------------
-- SELECT id, nome, email, cidade, segmento
-- FROM energia.unidades
-- WHERE email = 'contato410@empresa410.com.br';  -- usa o UNIQUE existente

-- ---------------------------------------------------------------------
-- Conferir o tamanho do índice (custo colateral em disco):
-- SELECT pg_size_pretty(pg_relation_size('energia.idx_unidades_upper_email'));
--
-- Para desfazer:
-- DROP INDEX energia.idx_unidades_upper_email;
-- =====================================================================
