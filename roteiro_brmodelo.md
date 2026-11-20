# Roteiro para desenhar os modelos (Parte 1)

## 1. Modelo Conceitual no BRModelo

Abra o BRModelo → **Novo → Modelo Conceitual**. Crie as entidades (retângulos), os
relacionamentos (losangos) e as cardinalidades abaixo. Atributo identificador = bolinha preenchida.

### Entidades e atributos

| Entidade | Atributos (identificador em **negrito**) |
|---|---|
| EQUIPE | **id**, nome, descricao, ativo, criado_em, atualizado_em |
| USUARIO | **id**, nome, email, senha_hash, cargo, ativo, senha_provisoria, criado_em, atualizado_em |
| CLIENTE | **id**, nome, ativo, criado_em, atualizado_em |
| PROJETO | **id**, nome, local_instalacao, descricao, ativo, criado_em, atualizado_em |
| TICKET | **id**, titulo, descricao, categoria, prioridade, status, sla_em, encerrado_em, criado_em, atualizado_em |
| RELATORIO | **id**, trabalho_realizado, materiais_utilizados, outros_detalhes, criado_em, atualizado_em |
| HISTORICO_TICKET | **id**, evento, descricao, criado_em |
| ATIVIDADE_CONTA | **id**, tipo, descricao, criado_em |
| AUDITORIA_TICKET | **id**, data_alteracao, prioridade_antiga, prioridade_nova, status_antigo, status_novo, msg |

### Relacionamentos

No BRModelo, a cardinalidade escrita **perto de uma entidade** diz com quantas ocorrências
dela a outra entidade se liga. As colunas abaixo já dizem o que escrever perto de cada uma.

| # | Entidade 1 | Relacionamento | Entidade 2 | Escrever perto da Entidade 1 | Escrever perto da Entidade 2 | Leitura |
|---|---|---|---|---|---|---|
| 1 | EQUIPE | PERTENCE | USUARIO | (0,1) | (0,n) | uma equipe tem 0..n usuários; um usuário está em 0..1 equipe |
| 2 | USUARIO (criador) | CRIA | USUARIO (criado) | (0,1) | (0,n) | auto-relacionamento: quem criou a conta |
| 3 | CLIENTE | POSSUI | PROJETO | (1,1) | (0,n) | todo projeto é de 1 cliente |
| 4 | EQUIPE | RESPONDE_POR | PROJETO | (1,1) | (0,n) | todo projeto tem 1 equipe principal |
| 5 | USUARIO (gestor) | GERENCIA | PROJETO | (1,1) | (0,n) | todo projeto tem 1 gestor |
| 6 | PROJETO | CONTEM | TICKET | (1,1) | (0,n) | todo ticket é de 1 projeto |
| 7 | USUARIO | ABRE | TICKET | (1,1) | (0,n) | todo ticket foi aberto por 1 usuário |
| 8 | USUARIO (técnico) | E_RESPONSAVEL | TICKET | (0,1) | (0,n) | ticket pode ou não ter técnico responsável |
| 9 | TICKET | ALOCA *(atributo criado_em)* | EQUIPE | (0,n) | (1,n) | **N:N** → vira a tabela `ticket_equipes` |
| 10 | TICKET | TEM | RELATORIO | (1,1) | (0,n) | relatório pertence a 1 ticket |
| 11 | USUARIO | ESCREVE | RELATORIO | (1,1) | (0,n) | relatório tem 1 autor |
| 12 | TICKET | REGISTRA | HISTORICO_TICKET | (1,1) | (0,n) | evento pertence a 1 ticket |
| 13 | USUARIO | AUTOR_DE | HISTORICO_TICKET | (0,1) | (0,n) | evento automático não tem autor |
| 14 | EQUIPE | EQUIPE_DO_EVENTO | HISTORICO_TICKET | (0,1) | (0,n) | equipe do autor no momento |
| 15 | EQUIPE | INICIA | HISTORICO_TICKET | (0,1) | (0,n) | só no evento ATIVIDADE_INICIADA |
| 16 | USUARIO | REALIZA | ATIVIDADE_CONTA | (1,1) | (0,n) | atividade é de 1 usuário |
| 17 | TICKET | AUDITADO_EM | AUDITORIA_TICKET | (1,1) | (0,n) | registro de auditoria é de 1 ticket |

Salvar como `modelo_conceitual.brM3` e exportar a imagem para o documento.

## 2. Modelo Lógico

Mais rápido (recomendado): **MySQL Workbench → Database → Reverse Engineer**, escolher o schema
`altave_av3` e avançar até o fim. Ele desenha todas as tabelas com PK/FK e as ligações.
Organizar as caixas e exportar: **File → Export → Export as PNG**.

Alternativa: no BRModelo, **Gerar Modelo Lógico** a partir do conceitual; o resultado deve
bater com o `01_DDL_criacao_tabelas.sql`.
