# Parte 5 - Painel de SLA (Express + MySQL)

Funcionalidade do projeto API (Sistema de Ordens de Serviço - Altave) implementada
sobre o banco da 3ª avaliação (`altave_av3`), **isolado** do banco da API do time.

| Endpoint | Objeto do banco usado |
|---|---|
| `GET /api/tickets?equipeId=` | FUNCTIONS `fn_status_sla` e `fn_nome_responsavel` (no SELECT) |
| `GET /api/alertas-sla?horas=24` | PROCEDURE `sp_gerar_alertas_sla` (IN horas, OUT qtd - usa cursor) |
| `POST /api/tickets/:id/equipes` | PROCEDURE `sp_alocar_equipe_ticket` (OUT msg) + trigger `trg_ticket_equipes_ai_historico` |
| `GET /api/tickets/:id/historico` | mostra o evento gravado pelo trigger |
| `GET /api/equipes`, `GET /api/equipes/:id/tecnicos`, `GET /api/tickets/:id/equipes` | apoio para a tela |

## Como executar
1. No MySQL Workbench, rodar `entrega/01`, `02` e `03` (cria o banco `altave_av3`).
2. Nesta pasta:
   ```
   npm install
   copy .env.example .env      (e colocar a senha do seu MySQL)
   npm start
   ```
3. Abrir http://localhost:3000

Na tela: a tabela mostra o SLA de cada ticket aberto (function); "Gerar alertas" chama a
procedure com cursor; clicando num ticket dá para pedir apoio de outra equipe (procedure),
e o histórico mostra o registro feito pelo trigger.
