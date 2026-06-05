-- Esquema inicial do estudo de caso A2: Energia IoT.
-- Indices auxiliares foram omitidos de proposito para que a equipe meca,
-- proponha e justifique as otimizacoes.

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

DROP SCHEMA IF EXISTS energia CASCADE;
CREATE SCHEMA energia;

CREATE TABLE energia.unidades (
    id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(140) NOT NULL,
    email VARCHAR(180) NOT NULL UNIQUE,
    documento VARCHAR(24) NOT NULL,
    cidade VARCHAR(80) NOT NULL,
    uf CHAR(2) NOT NULL,
    segmento VARCHAR(30) NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE energia.tecnicos (
    id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(140) NOT NULL,
    email VARCHAR(180) NOT NULL UNIQUE,
    equipe VARCHAR(30) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE energia.medidores (
    id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(80) NOT NULL UNIQUE,
    grupo VARCHAR(40) NOT NULL,
    sla_horas INTEGER NOT NULL CHECK (sla_horas > 0)
);

CREATE TABLE energia.leituras (
    id BIGSERIAL PRIMARY KEY,
    unidades_id BIGINT NOT NULL REFERENCES energia.unidades(id),
    tecnicos_id BIGINT REFERENCES energia.tecnicos(id),
    medidores_id BIGINT NOT NULL REFERENCES energia.medidores(id),
    status VARCHAR(24) NOT NULL CHECK (status IN ('aberto','em_andamento','aguardando_cliente','concluido','cancelado')),
    prioridade VARCHAR(10) NOT NULL CHECK (prioridade IN ('baixa','media','alta','critica')),
    titulo VARCHAR(180) NOT NULL,
    descricao TEXT NOT NULL,
    tags JSONB NOT NULL DEFAULT '{}'::jsonb,
    valor NUMERIC(12,2) NOT NULL DEFAULT 0,
    occurred_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP
);

CREATE TABLE energia.eventos_leitura (
    id BIGSERIAL PRIMARY KEY,
    leituras_id BIGINT NOT NULL REFERENCES energia.leituras(id),
    tipo VARCHAR(30) NOT NULL,
    canal VARCHAR(30) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    mensagem TEXT NOT NULL,
    occurred_at TIMESTAMP NOT NULL
);

CREATE TABLE energia.avaliacoes (
    id BIGSERIAL PRIMARY KEY,
    leituras_id BIGINT NOT NULL UNIQUE REFERENCES energia.leituras(id),
    nota INTEGER NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario TEXT,
    created_at TIMESTAMP NOT NULL
);

COMMENT ON SCHEMA energia IS 'Estudo de caso A2 - Energia IoT';
COMMENT ON TABLE energia.leituras IS 'Tabela principal grande, sem indices auxiliares para fins de otimizacao.';
COMMENT ON TABLE energia.eventos_leitura IS 'Tabela de eventos com milhoes de linhas, adequada para analisar FK, BRIN, GIN e work_mem.';
