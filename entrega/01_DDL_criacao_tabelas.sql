-- =====================================================================
-- 3ª Avaliação de Banco de Dados Relacional - 2º Semestre de 2026
-- Dupla: Guilherme Machado Silva / Nathan Ariel Damasio Leão - 2DSM
-- Projeto API: Sistema de Ordens de Serviço (tickets) - Altave
--
-- ARQUIVO 01 - DDL: criação do banco e das tabelas
-- Estrutura idêntica à do projeto API (consolidada a partir das
-- migrations do Prisma) + tabela auditoria_ticket (usada pelos triggers).
-- =====================================================================

DROP DATABASE IF EXISTS altave_av3;
CREATE DATABASE altave_av3
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE altave_av3;

-- ---------------------------------------------------------------------
-- EQUIPES: times técnicos que atendem os tickets
-- ---------------------------------------------------------------------
CREATE TABLE equipes (
    id            CHAR(36)     NOT NULL,
    nome          VARCHAR(100) NOT NULL,
    descricao     VARCHAR(255) NULL,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    atualizado_em DATETIME(3)  NOT NULL,
    CONSTRAINT pk_equipes PRIMARY KEY (id),
    CONSTRAINT uq_equipes_nome UNIQUE (nome)
);

-- ---------------------------------------------------------------------
-- USUARIOS: funcionários da Altave (técnicos, gestores, analistas)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id               CHAR(36)     NOT NULL,
    nome             VARCHAR(120) NOT NULL,
    email            VARCHAR(254) NOT NULL,
    senha_hash       VARCHAR(255) NOT NULL,
    cargo            ENUM('TECNICO','GESTOR','SUPORTE','SUPORTE_INTERNO','COMERCIAL') NOT NULL,
    ativo            BOOLEAN      NOT NULL DEFAULT TRUE,
    senha_provisoria BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em        DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    atualizado_em    DATETIME(3)  NOT NULL,
    equipe_id        CHAR(36)     NULL,
    criado_por_id    CHAR(36)     NULL,
    CONSTRAINT pk_usuarios PRIMARY KEY (id),
    CONSTRAINT uq_usuarios_email UNIQUE (email),
    INDEX ix_usuarios_equipe (equipe_id),
    CONSTRAINT usuarios_equipe_id_fkey FOREIGN KEY (equipe_id)
        REFERENCES equipes (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT usuarios_criado_por_id_fkey FOREIGN KEY (criado_por_id)
        REFERENCES usuarios (id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- CLIENTES: empresas atendidas pela Altave
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id            CHAR(36)     NOT NULL,
    nome          VARCHAR(150) NOT NULL,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    atualizado_em DATETIME(3)  NOT NULL,
    CONSTRAINT pk_clientes PRIMARY KEY (id),
    CONSTRAINT uq_clientes_nome UNIQUE (nome)
);

-- ---------------------------------------------------------------------
-- PROJETOS: instalação/serviço contratado por um cliente
-- ---------------------------------------------------------------------
CREATE TABLE projetos (
    id               CHAR(36)     NOT NULL,
    nome             VARCHAR(150) NOT NULL,
    local_instalacao VARCHAR(255) NOT NULL,
    descricao        TEXT         NULL,
    ativo            BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em        DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    atualizado_em    DATETIME(3)  NOT NULL,
    cliente_id       CHAR(36)     NOT NULL,
    equipe_id        CHAR(36)     NOT NULL,
    gestor_id        CHAR(36)     NOT NULL,
    CONSTRAINT pk_projetos PRIMARY KEY (id),
    CONSTRAINT uq_projetos_cliente_nome UNIQUE (cliente_id, nome),
    INDEX ix_projetos_equipe (equipe_id),
    INDEX ix_projetos_gestor (gestor_id),
    CONSTRAINT projetos_cliente_id_fkey FOREIGN KEY (cliente_id)
        REFERENCES clientes (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT projetos_equipe_id_fkey FOREIGN KEY (equipe_id)
        REFERENCES equipes (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT projetos_gestor_id_fkey FOREIGN KEY (gestor_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- TICKETS: ordens de serviço (instalação ou manutenção) de um projeto
-- ---------------------------------------------------------------------
CREATE TABLE tickets (
    id             CHAR(36)     NOT NULL,
    titulo         VARCHAR(180) NOT NULL,
    descricao      TEXT         NOT NULL,
    categoria      ENUM('MANUTENCAO','INSTALACAO') NOT NULL,
    prioridade     ENUM('BAIXA','MEDIA','ALTA','CRITICA') NOT NULL DEFAULT 'MEDIA',
    status         ENUM('NAO_INICIADO','EM_ANDAMENTO','SOLICITACAO_ENCERRAMENTO','ENCERRADO','EM_REVISAO')
                   NOT NULL DEFAULT 'EM_ANDAMENTO',
    sla_em         DATETIME(3)  NOT NULL,
    encerrado_em   DATETIME(3)  NULL,
    criado_em      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    atualizado_em  DATETIME(3)  NOT NULL,
    projeto_id     CHAR(36)     NOT NULL,
    aberto_por_id  CHAR(36)     NOT NULL,
    responsavel_id CHAR(36)     NULL,
    CONSTRAINT pk_tickets PRIMARY KEY (id),
    INDEX ix_tickets_fila (projeto_id, status, prioridade, criado_em),
    INDEX ix_tickets_sla (status, sla_em),
    INDEX ix_tickets_aberto_por (aberto_por_id),
    INDEX ix_tickets_responsavel (responsavel_id),
    CONSTRAINT tickets_projeto_id_fkey FOREIGN KEY (projeto_id)
        REFERENCES projetos (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT tickets_aberto_por_id_fkey FOREIGN KEY (aberto_por_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT tickets_responsavel_id_fkey FOREIGN KEY (responsavel_id)
        REFERENCES usuarios (id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- TICKET_EQUIPES: associação N:N entre tickets e equipes alocadas
-- ---------------------------------------------------------------------
CREATE TABLE ticket_equipes (
    id        CHAR(36)    NOT NULL,
    criado_em DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ticket_id CHAR(36)    NOT NULL,
    equipe_id CHAR(36)    NOT NULL,
    CONSTRAINT pk_ticket_equipes PRIMARY KEY (id),
    CONSTRAINT uq_ticket_equipes_ticket_equipe UNIQUE (ticket_id, equipe_id),
    INDEX ix_ticket_equipes_equipe (equipe_id),
    CONSTRAINT ticket_equipes_ticket_id_fkey FOREIGN KEY (ticket_id)
        REFERENCES tickets (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ticket_equipes_equipe_id_fkey FOREIGN KEY (equipe_id)
        REFERENCES equipes (id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- RELATORIOS: registro do trabalho realizado pelo técnico no ticket
-- ---------------------------------------------------------------------
CREATE TABLE relatorios (
    id                   CHAR(36)    NOT NULL,
    trabalho_realizado   TEXT        NOT NULL,
    materiais_utilizados TEXT        NOT NULL,
    outros_detalhes      TEXT        NOT NULL,
    criado_em            DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    atualizado_em        DATETIME(3) NOT NULL,
    ticket_id            CHAR(36)    NOT NULL,
    autor_id             CHAR(36)    NOT NULL,
    CONSTRAINT pk_relatorios PRIMARY KEY (id),
    INDEX ix_relatorios_ticket (ticket_id, criado_em),
    INDEX ix_relatorios_autor (autor_id),
    CONSTRAINT relatorios_ticket_id_fkey FOREIGN KEY (ticket_id)
        REFERENCES tickets (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT relatorios_autor_id_fkey FOREIGN KEY (autor_id)
        REFERENCES usuarios (id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- HISTORICO_TICKET: linha do tempo de eventos de cada ticket (logs)
-- ---------------------------------------------------------------------
CREATE TABLE historico_ticket (
    id               CHAR(36)    NOT NULL,
    evento           VARCHAR(50) NOT NULL,
    descricao        TEXT        NOT NULL,
    criado_em        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ticket_id        CHAR(36)    NOT NULL,
    usuario_id       CHAR(36)    NULL,
    equipe_id        CHAR(36)    NULL,
    inicio_equipe_id CHAR(36)    NULL,
    CONSTRAINT pk_historico_ticket PRIMARY KEY (id),
    CONSTRAINT uq_historico_inicio_equipe UNIQUE (ticket_id, inicio_equipe_id),
    INDEX ix_historico_ticket_data (ticket_id, criado_em),
    INDEX ix_historico_usuario (usuario_id),
    INDEX ix_historico_equipe (equipe_id),
    INDEX ix_historico_inicio_equipe (inicio_equipe_id),
    CONSTRAINT historico_ticket_ticket_id_fkey FOREIGN KEY (ticket_id)
        REFERENCES tickets (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT historico_ticket_usuario_id_fkey FOREIGN KEY (usuario_id)
        REFERENCES usuarios (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT historico_ticket_equipe_id_fkey FOREIGN KEY (equipe_id)
        REFERENCES equipes (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT historico_ticket_inicio_equipe_id_fkey FOREIGN KEY (inicio_equipe_id)
        REFERENCES equipes (id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- ATIVIDADES_CONTA: registro de atividades das contas de usuário
-- ---------------------------------------------------------------------
CREATE TABLE atividades_conta (
    id         CHAR(36)    NOT NULL,
    tipo       VARCHAR(20) NOT NULL,
    descricao  TEXT        NOT NULL,
    criado_em  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    usuario_id CHAR(36)    NOT NULL,
    CONSTRAINT pk_atividades_conta PRIMARY KEY (id),
    INDEX ix_atividades_conta_usuario_data (usuario_id, criado_em),
    CONSTRAINT atividades_conta_usuario_id_fkey FOREIGN KEY (usuario_id)
        REFERENCES usuarios (id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- AUDITORIA_TICKET (tabela da AV3): log de alterações de prioridade e
-- status dos tickets, alimentado por trigger (mesma ideia do func_log).
-- ---------------------------------------------------------------------
CREATE TABLE auditoria_ticket (
    id                INT          NOT NULL AUTO_INCREMENT,
    ticket_id         CHAR(36)     NOT NULL,
    data_alteracao    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    prioridade_antiga VARCHAR(10)  NULL,
    prioridade_nova   VARCHAR(10)  NULL,
    status_antigo     VARCHAR(30)  NULL,
    status_novo       VARCHAR(30)  NULL,
    msg               VARCHAR(255) NOT NULL,
    CONSTRAINT pk_auditoria_ticket PRIMARY KEY (id),
    INDEX ix_auditoria_ticket (ticket_id, data_alteracao),
    CONSTRAINT auditoria_ticket_ticket_id_fkey FOREIGN KEY (ticket_id)
        REFERENCES tickets (id) ON DELETE CASCADE ON UPDATE CASCADE
);
