-- =====================================================================
-- 3ª Avaliação de Banco de Dados Relacional - 2º Semestre de 2026
-- Dupla: Guilherme Machado Silva / Nathan Ariel Damasio Leão - 2DSM
--
-- ARQUIVO 04 - Testes (consultas usadas para os PRINTS do documento)
-- Executar bloco a bloco no MySQL Workbench depois dos arquivos 01, 02 e 03.
-- Os testes que alteram dados terminam com ROLLBACK (podem ser repetidos).
-- Obs.: resultados de SLA dependem da data/hora em que forem executados.
-- =====================================================================

USE altave_av3;

-- ---------------------------------------------------------------------
-- 0) Conferência da carga (pelo menos 50 linhas por tabela)
-- ---------------------------------------------------------------------
SELECT 'equipes' AS tabela, COUNT(*) AS registros FROM equipes
UNION ALL SELECT 'usuarios',         COUNT(*) FROM usuarios
UNION ALL SELECT 'clientes',         COUNT(*) FROM clientes
UNION ALL SELECT 'projetos',         COUNT(*) FROM projetos
UNION ALL SELECT 'tickets',          COUNT(*) FROM tickets
UNION ALL SELECT 'ticket_equipes',   COUNT(*) FROM ticket_equipes
UNION ALL SELECT 'relatorios',       COUNT(*) FROM relatorios
UNION ALL SELECT 'historico_ticket', COUNT(*) FROM historico_ticket
UNION ALL SELECT 'atividades_conta', COUNT(*) FROM atividades_conta
UNION ALL SELECT 'auditoria_ticket', COUNT(*) FROM auditoria_ticket;

-- ---------------------------------------------------------------------
-- Variáveis usadas nos testes (escolhidas por nome/condição, não por UUID)
-- ---------------------------------------------------------------------
SELECT id INTO @equipe_redes    FROM equipes  WHERE nome = 'Redes SJC';
SELECT id INTO @suporte_interno FROM usuarios WHERE cargo = 'SUPORTE_INTERNO' ORDER BY criado_em LIMIT 1;
SELECT id INTO @ticket_aberto   FROM tickets  WHERE status = 'EM_ANDAMENTO' ORDER BY sla_em LIMIT 1;
SELECT id INTO @ticket_encerrado FROM tickets WHERE status = 'ENCERRADO' ORDER BY encerrado_em DESC LIMIT 1;
SELECT id INTO @ticket_nao_iniciado FROM tickets WHERE status = 'NAO_INICIADO' LIMIT 1;
SELECT u.id INTO @tecnico_ok          -- técnico de uma equipe que está no ticket aberto
  FROM usuarios u INNER JOIN ticket_equipes te ON te.equipe_id = u.equipe_id
 WHERE te.ticket_id = @ticket_aberto AND u.cargo = 'TECNICO' AND u.ativo = TRUE LIMIT 1;
SELECT u.id INTO @tecnico_fora        -- técnico de uma equipe que NÃO está no ticket aberto
  FROM usuarios u
 WHERE u.cargo = 'TECNICO' AND u.ativo = TRUE AND u.equipe_id IS NOT NULL
   AND u.equipe_id NOT IN (SELECT equipe_id FROM ticket_equipes WHERE ticket_id = @ticket_aberto)
 LIMIT 1;

-- ---------------------------------------------------------------------
-- VIEWS
-- ---------------------------------------------------------------------
SELECT titulo, prioridade, ordem_prioridade, status, sla_em, cliente, responsavel
  FROM vw_tickets_detalhados
 WHERE status <> 'ENCERRADO'
 ORDER BY ordem_prioridade, sla_em
 LIMIT 15;

SELECT * FROM vw_carga_equipes ORDER BY tickets_abertos DESC;


-- =====================================================================
-- FUNCTIONS
-- =====================================================================

-- F1 - fn_status_sla
SELECT titulo, status, sla_em, fn_status_sla(ticket_id) AS situacao_sla
  FROM vw_tickets_detalhados
 ORDER BY sla_em DESC
 LIMIT 20;
SELECT fn_status_sla('nao-existe') AS ticket_inexistente;

-- F2 - fn_tickets_abertos_equipe
SELECT nome AS equipe, fn_tickets_abertos_equipe(id) AS tickets_abertos
  FROM equipes
 WHERE ativo = TRUE
 ORDER BY tickets_abertos DESC
 LIMIT 15;

-- F3 - fn_qtd_tickets_cliente
SELECT nome AS cliente,
       fn_qtd_tickets_cliente(id, 'TODOS')        AS total,
       fn_qtd_tickets_cliente(id, 'EM_ANDAMENTO') AS em_andamento,
       fn_qtd_tickets_cliente(id, 'ENCERRADO')    AS encerrados
  FROM clientes
 ORDER BY total DESC;

-- F4 - fn_percentual_sla_cliente
SELECT nome AS cliente, fn_percentual_sla_cliente(id) AS perc_sla_cumprido
  FROM clientes
 WHERE ativo = TRUE
 ORDER BY perc_sla_cumprido DESC;

-- F5 - fn_nome_responsavel
SELECT titulo, fn_nome_responsavel(id) AS responsavel
  FROM tickets
 ORDER BY criado_em DESC
 LIMIT 15;

-- F6 - fn_pode_registrar_log
SELECT fn_pode_registrar_log(@tecnico_ok,      @ticket_aberto)    AS tecnico_da_equipe,
       fn_pode_registrar_log(@tecnico_fora,    @ticket_aberto)    AS tecnico_de_outra_equipe,
       fn_pode_registrar_log(@tecnico_ok,      @ticket_encerrado) AS ticket_encerrado;


-- =====================================================================
-- STORED PROCEDURES
-- =====================================================================

-- P1 - sp_gerar_alertas_sla (cursor): tickets vencidos ou vencendo nas próximas 24h
CALL sp_gerar_alertas_sla(24, @qtd_alertas);
SELECT @qtd_alertas AS total_alertas;

-- P2 - sp_alocar_equipe_ticket
START TRANSACTION;
SELECT id INTO @equipe_apoio FROM equipes
 WHERE ativo = TRUE
   AND id NOT IN (SELECT equipe_id FROM ticket_equipes WHERE ticket_id = @ticket_aberto)
 ORDER BY nome LIMIT 1;
CALL sp_alocar_equipe_ticket(@ticket_aberto, @equipe_apoio, @tecnico_ok, @msg);
SELECT @msg AS resultado_1;                       -- sucesso
CALL sp_alocar_equipe_ticket(@ticket_aberto, @equipe_apoio, @tecnico_ok, @msg);
SELECT @msg AS resultado_2;                       -- equipe já alocada
CALL sp_alocar_equipe_ticket(@ticket_aberto, @equipe_redes, @tecnico_fora, @msg);
SELECT @msg AS resultado_3;                       -- usuário sem permissão
SELECT e.nome AS equipe, te.criado_em
  FROM ticket_equipes te INNER JOIN equipes e ON e.id = te.equipe_id
 WHERE te.ticket_id = @ticket_aberto;
ROLLBACK;

-- P3 - sp_relatorio_desempenho_equipes: 2º semestre, equipes com 5 ou mais tickets
CALL sp_relatorio_desempenho_equipes('2026-07-01', '2026-12-01', 5);

-- P4 - sp_ranking_tecnicos: todas as equipes e só a equipe Redes SJC
CALL sp_ranking_tecnicos(NULL);
CALL sp_ranking_tecnicos(@equipe_redes);

-- P5 - sp_escalonar_prioridade_vencidos (cursor)
START TRANSACTION;
SELECT prioridade, COUNT(*) AS qtd FROM tickets
 WHERE status <> 'ENCERRADO' AND sla_em < NOW() GROUP BY prioridade;   -- antes
CALL sp_escalonar_prioridade_vencidos(@qtd_escalonados);
SELECT @qtd_escalonados AS tickets_escalonados;
SELECT prioridade, COUNT(*) AS qtd FROM tickets
 WHERE status <> 'ENCERRADO' AND sla_em < NOW() GROUP BY prioridade;   -- depois
ROLLBACK;

-- P6 - sp_cadastrar_usuario
START TRANSACTION;
CALL sp_cadastrar_usuario('Marcos Teste Lima', 'marcos.lima@altave.com.br', 'TECNICO',
                          @equipe_redes, @suporte_interno, @msg);
SELECT @msg AS resultado_1;                       -- sucesso (mostra quem criou)
CALL sp_cadastrar_usuario('Marcos Teste Lima', 'marcos.lima@altave.com.br', 'TECNICO',
                          @equipe_redes, @suporte_interno, @msg);
SELECT @msg AS resultado_2;                       -- e-mail repetido
CALL sp_cadastrar_usuario('Outro Usuario', 'outro@altave.com.br', 'GESTOR',
                          NULL, @suporte_interno, @msg);
SELECT @msg AS resultado_3;                       -- gestor sem equipe
CALL sp_cadastrar_usuario('Outro Usuario', 'outro@altave.com.br', 'TECNICO',
                          @equipe_redes, @tecnico_ok, @msg);
SELECT @msg AS resultado_4;                       -- quem cadastra não é suporte interno
ROLLBACK;


-- =====================================================================
-- TRIGGERS
-- =====================================================================
SHOW TRIGGERS;

-- T1 - trg_tickets_ai_historico: abrir ticket grava TICKET_ABERTO no histórico
START TRANSACTION;
SELECT id INTO @projeto   FROM projetos WHERE ativo = TRUE ORDER BY nome LIMIT 1;
SELECT id INTO @comercial FROM usuarios WHERE cargo = 'COMERCIAL' AND ativo = TRUE LIMIT 1;
SET @novo_ticket = UUID();
INSERT INTO tickets (id, titulo, descricao, categoria, prioridade, status, sla_em,
                     criado_em, atualizado_em, projeto_id, aberto_por_id)
VALUES (@novo_ticket, 'Teste do trigger', 'Ticket criado para testar o trigger', 'MANUTENCAO',
        'ALTA', 'NAO_INICIADO', NOW() + INTERVAL 2 DAY, NOW(), NOW(), @projeto, @comercial);
SELECT evento, descricao, criado_em FROM historico_ticket WHERE ticket_id = @novo_ticket;
ROLLBACK;

-- T2 + T3 - encerrar um ticket: encerrado_em preenchido (T2) e auditoria gravada (T3)
START TRANSACTION;
UPDATE tickets SET status = 'ENCERRADO' WHERE id = @ticket_aberto;
SELECT titulo, status, encerrado_em, atualizado_em FROM tickets WHERE id = @ticket_aberto;
SELECT * FROM auditoria_ticket WHERE ticket_id = @ticket_aberto ORDER BY id DESC;
ROLLBACK;

-- T3 - auditoria de mudança de prioridade (vários tickets de uma vez - FOR EACH ROW)
START TRANSACTION;
UPDATE tickets SET prioridade = 'ALTA'
 WHERE status = 'EM_ANDAMENTO' AND prioridade = 'BAIXA';
SELECT * FROM auditoria_ticket ORDER BY id DESC LIMIT 10;
ROLLBACK;

-- T4 - trg_ticket_equipes_ai_historico: alocar equipe grava EQUIPE_ALOCADA
START TRANSACTION;
INSERT INTO ticket_equipes (id, criado_em, ticket_id, equipe_id)
VALUES (UUID(), NOW(), @ticket_aberto, @equipe_redes);
SELECT evento, descricao, criado_em FROM historico_ticket
 WHERE ticket_id = @ticket_aberto ORDER BY criado_em DESC LIMIT 3;
ROLLBACK;

-- T5 - trg_usuarios_au_atividade: desativar uma conta
START TRANSACTION;
UPDATE usuarios SET ativo = FALSE WHERE id = @tecnico_fora;
SELECT u.nome, a.tipo, a.descricao, a.criado_em
  FROM atividades_conta a INNER JOIN usuarios u ON u.id = a.usuario_id
 WHERE a.usuario_id = @tecnico_fora ORDER BY a.criado_em DESC LIMIT 3;
ROLLBACK;

-- T6 - trg_relatorios_ai_inicia_ticket: 1º relatório tira o ticket de NAO_INICIADO
START TRANSACTION;
SELECT titulo, status FROM tickets WHERE id = @ticket_nao_iniciado;      -- antes
SELECT u.id INTO @autor FROM usuarios u
 INNER JOIN ticket_equipes te ON te.equipe_id = u.equipe_id
 WHERE te.ticket_id = @ticket_nao_iniciado LIMIT 1;
INSERT INTO relatorios (id, trabalho_realizado, materiais_utilizados, outros_detalhes,
                        criado_em, atualizado_em, ticket_id, autor_id)
VALUES (UUID(), 'Visita inicial realizada', 'Nenhum', 'Sem observações.',
        NOW(), NOW(), @ticket_nao_iniciado, @autor);
SELECT titulo, status, atualizado_em FROM tickets WHERE id = @ticket_nao_iniciado;  -- depois
ROLLBACK;
