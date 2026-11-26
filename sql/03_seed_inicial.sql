-- =============================================================================
-- 05_seed_inicial.sql
-- Dados Iniciais de Governança Clínica (CONITEC/SUS e Agentes de IA)
-- =============================================================================

-- Limpeza segura com reinício das sequences (permite reexecutar sem duplicar IDs)
TRUNCATE TABLE fundamenta, parecer_agente, diretriz_clinica, agente_ia RESTART IDENTITY CASCADE;

-- 1. DIRETRIZ_CLINICA: Protocolos oficiais do Ministério da Saúde / CONITEC
INSERT INTO diretriz_clinica (titulo_protocolo) VALUES
    ('PCDT Sepse e Choque Séptico em Adultos - CONITEC/MS'),
    ('PCDT Injúria Renal Aguda e Ajuste de Antimicrobianos - CONITEC/MS'),
    ('Diretriz Brasileira de Terapia Intensiva e Monitoramento SOFA - AMIB/MS'),
    ('Protocolo de Segurança na Prescrição, Uso e Administração de Medicamentos - ANVISA/MS'),
    ('PCDT Insuficiência Respiratória Aguda e Ventilação Mecânica - CONITEC/MS');

-- 2. AGENTE_IA: Agentes especialistas da Junta Deliberativa
INSERT INTO agente_ia (tipo_agente) VALUES
    ('Risco Clínico e Triagem (SOFA)'),
    ('Diagnóstico Diferencial / Advogado do Diabo'),
    ('Auditoria Renal e Farmacovigilância'),
    ('Conformidade de Protocolos CONITEC/SUS');