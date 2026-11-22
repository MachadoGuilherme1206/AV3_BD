-- =====================================================================
-- 3ª Avaliação de Banco de Dados Relacional - 2º Semestre de 2026
-- Dupla: Guilherme Machado Silva / Nathan Ariel Damasio Leão - 2DSM
-- =====================================================================

USE altave_av3;

-- =====================================================================
-- VIEWS
-- =====================================================================

-- ---------------------------------------------------------------------
-- VIEW 1 - vw_tickets_detalhados
-- Problema: as telas precisam do ticket junto com o nome do projeto, do
-- cliente, de quem abriu e do técnico responsável. A view guarda essas
-- junções (INNER JOIN e LEFT JOIN, pois nem todo ticket tem responsável)
-- e numera a prioridade para ordenar a fila (CASE).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tickets_detalhados AS
SELECT t.id      AS ticket_id,
       t.titulo,
       t.categoria,
       t.prioridade,
       CASE
           WHEN t.prioridade = 'CRITICA' THEN 1
           WHEN t.prioridade = 'ALTA'    THEN 2
           WHEN t.prioridade = 'MEDIA'   THEN 3
           ELSE 4
       END       AS ordem_prioridade,
       t.status,
       t.criado_em,
       t.sla_em,
       t.encerrado_em,
       p.nome    AS projeto,
       c.id      AS cliente_id,
       c.nome    AS cliente,
       ab.nome   AS aberto_por,
       r.nome    AS responsavel
FROM tickets t
INNER JOIN projetos p  ON p.id  = t.projeto_id
INNER JOIN clientes c  ON c.id  = p.cliente_id
INNER JOIN usuarios ab ON ab.id = t.aberto_por_id
LEFT  JOIN usuarios r  ON r.id  = t.responsavel_id;

-- ---------------------------------------------------------------------
-- VIEW 2 - vw_carga_equipes
-- Problema: o gestor quer ver a carga de cada equipe, inclusive equipes
-- sem nenhum ticket (LEFT JOIN). GROUP BY com COUNT e SUM.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_carga_equipes
    (equipe, total_tickets, tickets_abertos, tickets_encerrados) AS
SELECT e.nome,
       COUNT(t.id),
       SUM(CASE WHEN t.status <> 'ENCERRADO' THEN 1 ELSE 0 END),
       SUM(CASE WHEN t.status =  'ENCERRADO' THEN 1 ELSE 0 END)
FROM equipes e
LEFT JOIN ticket_equipes te ON te.equipe_id = e.id
LEFT JOIN tickets t         ON t.id = te.ticket_id
WHERE e.ativo = TRUE
GROUP BY e.nome;


-- =====================================================================
-- FUNCTIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- FUNCTION 1 - fn_status_sla
-- Problema (US 5 - indicador visual de SLA): dizer a situação do SLA de
-- um ticket: NO_PRAZO, VENCE_EM_24H, VENCIDO, ENCERRADO_NO_PRAZO ou
-- ENCERRADO_ATRASADO. Ticket inexistente -> 'INEXISTENTE' (HANDLER).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_status_sla;
DELIMITER $$
CREATE FUNCTION fn_status_sla(p_ticket_id CHAR(36))
RETURNS VARCHAR(20)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_status    VARCHAR(30);
    DECLARE v_sla       DATETIME;
    DECLARE v_encerrado DATETIME;
    DECLARE v_resultado VARCHAR(20);
    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_resultado = 'INEXISTENTE';

    SELECT status, sla_em, encerrado_em
      INTO v_status, v_sla, v_encerrado
      FROM tickets
     WHERE id = p_ticket_id;

    IF v_resultado IS NULL THEN
        SET v_resultado =
            CASE
                WHEN v_status = 'ENCERRADO' AND v_encerrado <= v_sla THEN 'ENCERRADO_NO_PRAZO'
                WHEN v_status = 'ENCERRADO'                          THEN 'ENCERRADO_ATRASADO'
                WHEN v_sla < NOW()                                   THEN 'VENCIDO'
                WHEN v_sla <= NOW() + INTERVAL 24 HOUR               THEN 'VENCE_EM_24H'
                ELSE 'NO_PRAZO'
            END;
    END IF;

    RETURN v_resultado;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- FUNCTION 2 - fn_tickets_abertos_equipe
-- Problema (US 2/13): quantos tickets não encerrados estão com a equipe.
-- INNER JOIN + COUNT.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_tickets_abertos_equipe;
DELIMITER $$
CREATE FUNCTION fn_tickets_abertos_equipe(p_equipe_id CHAR(36))
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_qtd INT;

    SELECT COUNT(*)
      INTO v_qtd
      FROM ticket_equipes te
     INNER JOIN tickets t ON t.id = te.ticket_id
     WHERE te.equipe_id = p_equipe_id
       AND t.status <> 'ENCERRADO';

    RETURN v_qtd;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- FUNCTION 3 - fn_qtd_tickets_cliente
-- Problema: contar os tickets de um cliente, todos ou só de um status.
-- p_status = 'TODOS' conta tudo. IF/ELSE + INNER JOIN + COUNT.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_qtd_tickets_cliente;
DELIMITER $$
CREATE FUNCTION fn_qtd_tickets_cliente(p_cliente_id CHAR(36), p_status VARCHAR(30))
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_qtd INT;

    IF p_status = 'TODOS' THEN
        SELECT COUNT(*) INTO v_qtd
          FROM tickets t
         INNER JOIN projetos p ON p.id = t.projeto_id
         WHERE p.cliente_id = p_cliente_id;
    ELSE
        SELECT COUNT(*) INTO v_qtd
          FROM tickets t
         INNER JOIN projetos p ON p.id = t.projeto_id
         WHERE p.cliente_id = p_cliente_id
           AND t.status = p_status;
    END IF;

    RETURN v_qtd;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- FUNCTION 4 - fn_percentual_sla_cliente
-- Problema: para a liderança, qual o % de tickets encerrados do cliente
-- que foram resolvidos dentro do SLA. SUM(CASE), COUNT e ROUND.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_percentual_sla_cliente;
DELIMITER $$
CREATE FUNCTION fn_percentual_sla_cliente(p_cliente_id CHAR(36))
RETURNS DECIMAL(5,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total    INT;
    DECLARE v_no_prazo INT;

    SELECT COUNT(*),
           SUM(CASE WHEN t.encerrado_em <= t.sla_em THEN 1 ELSE 0 END)
      INTO v_total, v_no_prazo
      FROM tickets t
     INNER JOIN projetos p ON p.id = t.projeto_id
     WHERE p.cliente_id = p_cliente_id
       AND t.status = 'ENCERRADO';

    IF v_total = 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND(v_no_prazo * 100 / v_total, 2);
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- FUNCTION 5 - fn_nome_responsavel
-- Problema: mostrar o técnico responsável pelo ticket; se o ticket não
-- tiver responsável, retornar 'Sem responsável' (CONTINUE HANDLER, igual
-- ao exemplo fn_busca_nome da aula).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_nome_responsavel;
DELIMITER $$
CREATE FUNCTION fn_nome_responsavel(p_ticket_id CHAR(36))
RETURNS VARCHAR(120)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_nome VARCHAR(120);
    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_nome = 'Sem responsável';

    SELECT u.nome
      INTO v_nome
      FROM tickets t
     INNER JOIN usuarios u ON u.id = t.responsavel_id
     WHERE t.id = p_ticket_id;

    RETURN v_nome;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- FUNCTION 6 - fn_pode_registrar_log
-- Problema (US 4): saber se o usuário pode atuar no ticket. Regras da
-- API: usuário ativo, ticket não encerrado e a equipe do usuário alocada
-- no ticket (EXISTS). Retorna 'PERMITIDO' ou o motivo.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_pode_registrar_log;
DELIMITER $$
CREATE FUNCTION fn_pode_registrar_log(p_usuario_id CHAR(36), p_ticket_id CHAR(36))
RETURNS VARCHAR(60)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    IF NOT EXISTS (SELECT * FROM usuarios WHERE id = p_usuario_id AND ativo = TRUE) THEN
        RETURN 'Usuário inexistente ou inativo';
    ELSEIF EXISTS (SELECT * FROM tickets WHERE id = p_ticket_id AND status = 'ENCERRADO') THEN
        RETURN 'Ticket encerrado';
    ELSEIF NOT EXISTS (SELECT *
                         FROM ticket_equipes te
                        INNER JOIN usuarios u ON u.equipe_id = te.equipe_id
                        WHERE te.ticket_id = p_ticket_id
                          AND u.id = p_usuario_id) THEN
        RETURN 'Equipe do usuário não está no ticket';
    ELSE
        RETURN 'PERMITIDO';
    END IF;
END $$
DELIMITER ;


-- =====================================================================
-- STORED PROCEDURES
-- =====================================================================

-- ---------------------------------------------------------------------
-- PROCEDURE 1 - sp_gerar_alertas_sla  (CURSOR)
-- Problema (US 19): listar os alertas de SLA para os gestores - tickets
-- abertos vencidos ou que vencem nas próximas p_horas. O CURSOR percorre
-- esses tickets, usa fn_status_sla em cada um, busca o gestor do projeto
-- e grava o alerta numa tabela temporária, que é exibida no final.
-- p_qtd (OUT) devolve quantos alertas foram gerados.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_gerar_alertas_sla;
DELIMITER $$
CREATE PROCEDURE sp_gerar_alertas_sla(IN p_horas INT, OUT p_qtd INT)
BEGIN
    DECLARE fim          BOOLEAN DEFAULT FALSE;
    DECLARE v_ticket_id  CHAR(36);
    DECLARE v_titulo     VARCHAR(180);
    DECLARE v_prioridade VARCHAR(10);
    DECLARE v_sla        DATETIME;
    DECLARE v_gestor     VARCHAR(120);

    DECLARE cur_tickets CURSOR FOR
        SELECT t.id, t.titulo, t.prioridade, t.sla_em, g.nome
          FROM tickets t
         INNER JOIN projetos p ON p.id = t.projeto_id
         INNER JOIN usuarios g ON g.id = p.gestor_id
         WHERE t.status <> 'ENCERRADO'
           AND t.sla_em <= NOW() + INTERVAL p_horas HOUR;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fim = TRUE;

    DROP TEMPORARY TABLE IF EXISTS alertas_sla;
    CREATE TEMPORARY TABLE alertas_sla (
        ticket_id  CHAR(36),
        titulo     VARCHAR(180),
        prioridade VARCHAR(10),
        sla_em     DATETIME,
        situacao   VARCHAR(20),
        gestor     VARCHAR(120),
        mensagem   VARCHAR(300)
    );

    SET p_qtd = 0;
    OPEN cur_tickets;
    percorre: LOOP
        FETCH cur_tickets INTO v_ticket_id, v_titulo, v_prioridade, v_sla, v_gestor;
        IF fim THEN
            LEAVE percorre;
        END IF;

        INSERT INTO alertas_sla
        VALUES (v_ticket_id, v_titulo, v_prioridade, v_sla, fn_status_sla(v_ticket_id), v_gestor,
                CONCAT('Gestor ', v_gestor, ': o ticket "', v_titulo, '" tem SLA em ', v_sla));

        SET p_qtd = p_qtd + 1;
    END LOOP;
    CLOSE cur_tickets;

    SELECT * FROM alertas_sla ORDER BY sla_em;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- PROCEDURE 2 - sp_alocar_equipe_ticket
-- Problema (US 22): pedir apoio de outra equipe num ticket. Antes de
-- inserir, verifica (como o InserirClienteSeguro da aula): se quem pede
-- pode atuar no ticket (fn_pode_registrar_log), se a equipe existe e está
-- ativa e se ela já não está alocada. O log no histórico é gravado pelo
-- trigger trg_ticket_equipes_ai_historico. p_msg (OUT) = resultado.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_alocar_equipe_ticket;
DELIMITER $$
CREATE PROCEDURE sp_alocar_equipe_ticket(
    IN  p_ticket_id  CHAR(36),
    IN  p_equipe_id  CHAR(36),
    IN  p_usuario_id CHAR(36),
    OUT p_msg        VARCHAR(150))
BEGIN
    DECLARE v_permissao VARCHAR(60);

    SET v_permissao = fn_pode_registrar_log(p_usuario_id, p_ticket_id);

    IF v_permissao <> 'PERMITIDO' THEN
        SET p_msg = CONCAT('Não permitido: ', v_permissao);
    ELSEIF NOT EXISTS (SELECT * FROM equipes WHERE id = p_equipe_id AND ativo = TRUE) THEN
        SET p_msg = 'Equipe inexistente ou inativa.';
    ELSEIF EXISTS (SELECT * FROM ticket_equipes
                    WHERE ticket_id = p_ticket_id AND equipe_id = p_equipe_id) THEN
        SET p_msg = 'Equipe já está alocada neste ticket.';
    ELSE
        INSERT INTO ticket_equipes (id, criado_em, ticket_id, equipe_id)
        VALUES (UUID(), NOW(), p_ticket_id, p_equipe_id);
        SET p_msg = 'Equipe alocada com sucesso.';
    END IF;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- PROCEDURE 3 - sp_relatorio_desempenho_equipes
-- Problema: relatório gerencial por equipe num período - total de
-- tickets, abertos, encerrados e % encerrado dentro do SLA.
-- LEFT JOIN, GROUP BY, COUNT/SUM, ROUND, CASE e HAVING.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_relatorio_desempenho_equipes;
DELIMITER $$
CREATE PROCEDURE sp_relatorio_desempenho_equipes(
    IN p_inicio      DATE,
    IN p_fim         DATE,
    IN p_min_tickets INT)
BEGIN
    SELECT e.nome      AS equipe,
           COUNT(t.id) AS total_tickets,
           SUM(CASE WHEN t.status <> 'ENCERRADO' THEN 1 ELSE 0 END) AS abertos,
           SUM(CASE WHEN t.status =  'ENCERRADO' THEN 1 ELSE 0 END) AS encerrados,
           ROUND(SUM(CASE WHEN t.encerrado_em <= t.sla_em THEN 1 ELSE 0 END) * 100
                 / SUM(CASE WHEN t.status = 'ENCERRADO' THEN 1 ELSE 0 END), 2) AS perc_sla_cumprido
      FROM equipes e
      LEFT JOIN ticket_equipes te ON te.equipe_id = e.id
      LEFT JOIN tickets t         ON t.id = te.ticket_id
                                 AND t.criado_em BETWEEN p_inicio AND p_fim
     WHERE e.ativo = TRUE
     GROUP BY e.nome
    HAVING COUNT(t.id) >= p_min_tickets
     ORDER BY perc_sla_cumprido DESC;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- PROCEDURE 4 - sp_ranking_tecnicos
-- Problema: o gestor quer ver quantos relatórios de trabalho cada técnico
-- registrou, inclusive quem ainda não registrou nenhum (RIGHT JOIN).
-- GROUP BY + COUNT e subconsulta com ALL para marcar o técnico com mais
-- relatórios que todos os outros. p_equipe_id NULL = todas as equipes.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ranking_tecnicos;
DELIMITER $$
CREATE PROCEDURE sp_ranking_tecnicos(IN p_equipe_id CHAR(36))
BEGIN
    SELECT u.nome      AS tecnico,
           e.nome      AS equipe,
           COUNT(r.id) AS qtd_relatorios,
           CASE
               WHEN COUNT(r.id) >= ALL (SELECT COUNT(*)
                                          FROM relatorios
                                         GROUP BY autor_id)
               THEN 'MAIOR PRODUÇÃO'
               WHEN COUNT(r.id) = 0 THEN 'SEM REGISTROS'
               ELSE ''
           END         AS observacao
      FROM relatorios r
     RIGHT JOIN usuarios u ON u.id = r.autor_id
      LEFT JOIN equipes e  ON e.id = u.equipe_id
     WHERE u.cargo = 'TECNICO'
       AND (p_equipe_id IS NULL OR u.equipe_id = p_equipe_id)
     GROUP BY u.nome, e.nome
     ORDER BY qtd_relatorios DESC;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- PROCEDURE 5 - sp_escalonar_prioridade_vencidos  (CURSOR)
-- Problema (US 6/7): tickets abertos com SLA vencido precisam subir na
-- fila. O CURSOR percorre os vencidos que ainda não são CRÍTICOS e sobe a
-- prioridade um nível (CASE). Cada UPDATE dispara o trigger de auditoria.
-- p_qtd (OUT) = quantos tickets foram escalonados.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_escalonar_prioridade_vencidos;
DELIMITER $$
CREATE PROCEDURE sp_escalonar_prioridade_vencidos(OUT p_qtd INT)
BEGIN
    DECLARE fim          BOOLEAN DEFAULT FALSE;
    DECLARE v_id         CHAR(36);
    DECLARE v_prioridade VARCHAR(10);

    DECLARE cur_vencidos CURSOR FOR
        SELECT id, prioridade
          FROM tickets
         WHERE status <> 'ENCERRADO'
           AND sla_em < NOW()
           AND prioridade <> 'CRITICA';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fim = TRUE;

    SET p_qtd = 0;
    OPEN cur_vencidos;
    percorre: LOOP
        FETCH cur_vencidos INTO v_id, v_prioridade;
        IF fim THEN
            LEAVE percorre;
        END IF;

        UPDATE tickets
           SET prioridade = CASE
                                WHEN v_prioridade = 'BAIXA' THEN 'MEDIA'
                                WHEN v_prioridade = 'MEDIA' THEN 'ALTA'
                                ELSE 'CRITICA'
                            END
         WHERE id = v_id;

        SET p_qtd = p_qtd + 1;
    END LOOP;
    CLOSE cur_vencidos;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- PROCEDURE 6 - sp_cadastrar_usuario
-- Problema (US 9/14/15/16): cadastrar contas com segurança - só um
-- SUPORTE_INTERNO ativo cadastra, e-mail não pode repetir (EXISTS) e
-- técnico/gestor precisa de equipe. Ao final mostra o usuário criado e
-- quem o criou (AUTO-JUNÇÃO da tabela usuarios).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cadastrar_usuario;
DELIMITER $$
CREATE PROCEDURE sp_cadastrar_usuario(
    IN  p_nome       VARCHAR(120),
    IN  p_email      VARCHAR(254),
    IN  p_cargo      VARCHAR(20),
    IN  p_equipe_id  CHAR(36),
    IN  p_criado_por CHAR(36),
    OUT p_msg        VARCHAR(150))
BEGIN
    IF NOT EXISTS (SELECT * FROM usuarios
                    WHERE id = p_criado_por AND cargo = 'SUPORTE_INTERNO' AND ativo = TRUE) THEN
        SET p_msg = 'Somente um Suporte Interno ativo pode cadastrar contas.';
    ELSEIF EXISTS (SELECT * FROM usuarios WHERE email = p_email) THEN
        SET p_msg = 'E-mail já cadastrado.';
    ELSEIF p_cargo IN ('TECNICO', 'GESTOR') AND p_equipe_id IS NULL THEN
        SET p_msg = 'Técnico e gestor precisam de uma equipe.';
    ELSE
        INSERT INTO usuarios (id, nome, email, senha_hash, cargo, ativo, senha_provisoria,
                              criado_em, atualizado_em, equipe_id, criado_por_id)
        VALUES (UUID(), p_nome, p_email,
                '$2b$10$o9rW/g93OfteIi6cgHWO5e9Q1MzTBNGUmuPH9DBUKb0I0RrKpAXne',
                p_cargo, TRUE, TRUE, NOW(), NOW(), p_equipe_id, p_criado_por);

        SET p_msg = 'Usuário cadastrado com sucesso.';

        SELECT u.nome AS usuario, u.email, u.cargo, c.nome AS criado_por
          FROM usuarios u
         INNER JOIN usuarios c ON c.id = u.criado_por_id
         WHERE u.email = p_email;
    END IF;
END $$
DELIMITER ;


-- =====================================================================
-- TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- TRIGGER 1 - trg_tickets_ai_historico  (AFTER INSERT ON tickets)
-- Problema: todo ticket aberto deve aparecer na linha do tempo. Ao
-- inserir um ticket, grava o evento TICKET_ABERTO no histórico.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_tickets_ai_historico;
DELIMITER $$
CREATE TRIGGER trg_tickets_ai_historico
AFTER INSERT ON tickets
FOR EACH ROW
BEGIN
    INSERT INTO historico_ticket (id, evento, descricao, criado_em, ticket_id, usuario_id)
    VALUES (UUID(), 'TICKET_ABERTO',
            CONCAT('Ticket aberto com prioridade ', NEW.prioridade, ' e SLA em ', NEW.sla_em),
            NOW(), NEW.id, NEW.aberto_por_id);
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER 2 - trg_tickets_bu_datas  (BEFORE UPDATE ON tickets)
-- Problema: preencher datas automaticamente. Quando o status muda para
-- ENCERRADO, grava encerrado_em; toda alteração atualiza atualizado_em.
-- (BEFORE permite mudar os valores NEW antes de gravar.)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_tickets_bu_datas;
DELIMITER $$
CREATE TRIGGER trg_tickets_bu_datas
BEFORE UPDATE ON tickets
FOR EACH ROW
BEGIN
    IF NEW.status = 'ENCERRADO' AND OLD.status <> 'ENCERRADO' THEN
        SET NEW.encerrado_em = NOW();
    END IF;
    SET NEW.atualizado_em = NOW();
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER 3 - trg_tickets_au_auditoria  (AFTER UPDATE ON tickets)
-- Problema: auditoria - registrar valor antigo e novo sempre que a
-- prioridade ou o status do ticket mudar (como o Imp_altera_Salarial).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_tickets_au_auditoria;
DELIMITER $$
CREATE TRIGGER trg_tickets_au_auditoria
AFTER UPDATE ON tickets
FOR EACH ROW
BEGIN
    IF NEW.prioridade <> OLD.prioridade OR NEW.status <> OLD.status THEN
        INSERT INTO auditoria_ticket (ticket_id, data_alteracao, prioridade_antiga, prioridade_nova,
                                      status_antigo, status_novo, msg)
        VALUES (NEW.id, NOW(), OLD.prioridade, NEW.prioridade, OLD.status, NEW.status,
                CONCAT('Prioridade antiga: ', OLD.prioridade, ' | Nova prioridade: ', NEW.prioridade,
                       ' | Status antigo: ', OLD.status, ' | Novo status: ', NEW.status));
    END IF;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER 4 - trg_ticket_equipes_ai_historico  (AFTER INSERT ON ticket_equipes)
-- Problema: quando uma equipe é alocada a um ticket, registrar o evento
-- EQUIPE_ALOCADA no histórico com o nome da equipe (subconsulta).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ticket_equipes_ai_historico;
DELIMITER $$
CREATE TRIGGER trg_ticket_equipes_ai_historico
AFTER INSERT ON ticket_equipes
FOR EACH ROW
BEGIN
    INSERT INTO historico_ticket (id, evento, descricao, criado_em, ticket_id, equipe_id)
    VALUES (UUID(), 'EQUIPE_ALOCADA',
            CONCAT('Equipe ', (SELECT nome FROM equipes WHERE id = NEW.equipe_id),
                   ' foi alocada no ticket.'),
            NOW(), NEW.ticket_id, NEW.equipe_id);
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER 5 - trg_usuarios_au_atividade  (AFTER UPDATE ON usuarios)
-- Problema (US 23): quando uma conta é desativada ou reativada, registrar
-- automaticamente nas atividades da conta.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_usuarios_au_atividade;
DELIMITER $$
CREATE TRIGGER trg_usuarios_au_atividade
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
    IF NEW.ativo <> OLD.ativo THEN
        INSERT INTO atividades_conta (id, tipo, descricao, criado_em, usuario_id)
        VALUES (UUID(), 'CONTA',
                CASE WHEN NEW.ativo = TRUE THEN 'Conta reativada.' ELSE 'Conta desativada.' END,
                NOW(), NEW.id);
    END IF;
END $$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER 6 - trg_relatorios_ai_inicia_ticket  (AFTER INSERT ON relatorios)
-- Problema: quando o técnico registra o primeiro relatório de trabalho num
-- ticket NAO_INICIADO, o ticket passa automaticamente para EM_ANDAMENTO.
-- (Esse UPDATE dispara também os triggers 2 e 3.)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_relatorios_ai_inicia_ticket;
DELIMITER $$
CREATE TRIGGER trg_relatorios_ai_inicia_ticket
AFTER INSERT ON relatorios
FOR EACH ROW
BEGIN
    UPDATE tickets
       SET status = 'EM_ANDAMENTO'
     WHERE id = NEW.ticket_id
       AND status = 'NAO_INICIADO';
END $$
DELIMITER ;
