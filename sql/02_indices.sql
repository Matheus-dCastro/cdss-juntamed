-- =============================================================================
-- 03_indices.sql
-- Índices de Desempenho (Spec 1 e FKs críticas)
-- =============================================================================

-- Spec 1 (listar_exames_criticos_atendimento):
-- Índice composto B-Tree para filtrar por hadm_id e flag_anormal = TRUE
-- com ordenação temporal decrescente em custo O(log N)
CREATE INDEX IF NOT EXISTS idx_exame_clinico_criticos
    ON exame_clinico (hadm_id, flag_anormal, charttime DESC);

-- Índices em FKs críticas para acelerar JOINs e validações das Regras R2-R8
CREATE INDEX IF NOT EXISTS idx_atendimento_subject_id
    ON atendimento (subject_id);

CREATE INDEX IF NOT EXISTS idx_atendimento_crm
    ON atendimento (crm);

CREATE INDEX IF NOT EXISTS idx_sessao_junta_hadm_id
    ON sessao_junta (hadm_id);

CREATE INDEX IF NOT EXISTS idx_parecer_agente_id_agente
    ON parecer_agente (id_agente);

CREATE INDEX IF NOT EXISTS idx_prescreve_num_registro
    ON prescreve (num_registro);

-- Busca por situação/risco na prescrição (Spec 3 / Regra R8)
CREATE INDEX IF NOT EXISTS idx_medicamento_situacao_risco
    ON medicamento (situacao_registro, categoria_risco_renal);