// =====================================================================
// 3ª Avaliação de BD - Parte 5: conexão do projeto API ao banco da AV3
// Funcionalidade: PAINEL DE SLA DOS TICKETS (US 5, 19 e 22 do backlog)
//
// Objetos do banco usados:
//   FUNCTION  fn_status_sla             -> situação do SLA de cada ticket
//   FUNCTION  fn_nome_responsavel       -> técnico responsável
//   PROCEDURE sp_gerar_alertas_sla      -> lista de alertas (cursor)
//   PROCEDURE sp_alocar_equipe_ticket   -> pedir apoio de outra equipe
// =====================================================================
const express = require("express");
const path = require("path");
const pool = require("./db");

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

// ---------------------------------------------------------------------
// GET /api/equipes - lista de equipes ativas (para os filtros da tela)
// ---------------------------------------------------------------------
app.get("/api/equipes", async (req, res) => {
  try {
    const [linhas] = await pool.query(
      "SELECT id, nome FROM equipes WHERE ativo = TRUE ORDER BY nome"
    );
    res.json(linhas);
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  }
});

// ---------------------------------------------------------------------
// GET /api/equipes/:id/tecnicos - técnicos ativos de uma equipe
// (simula o "usuário logado" que vai pedir apoio)
// ---------------------------------------------------------------------
app.get("/api/equipes/:id/tecnicos", async (req, res) => {
  try {
    const [linhas] = await pool.query(
      "SELECT id, nome FROM usuarios WHERE equipe_id = ? AND cargo = 'TECNICO' AND ativo = TRUE ORDER BY nome",
      [req.params.id]
    );
    res.json(linhas);
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  }
});

// ---------------------------------------------------------------------
// GET /api/tickets?equipeId=... - tickets abertos com o indicador de SLA
// Usa as FUNCTIONS fn_status_sla e fn_nome_responsavel dentro do SELECT.
// ---------------------------------------------------------------------
app.get("/api/tickets", async (req, res) => {
  try {
    const { equipeId } = req.query;
    let sql = `
      SELECT v.ticket_id, v.titulo, v.prioridade, v.status, v.sla_em, v.cliente,
             fn_status_sla(v.ticket_id)       AS situacao_sla,
             fn_nome_responsavel(v.ticket_id) AS responsavel
        FROM vw_tickets_detalhados v
       WHERE v.status <> 'ENCERRADO'`;
    const params = [];
    if (equipeId) {
      sql += " AND EXISTS (SELECT * FROM ticket_equipes te WHERE te.ticket_id = v.ticket_id AND te.equipe_id = ?)";
      params.push(equipeId);
    }
    sql += " ORDER BY v.ordem_prioridade, v.sla_em";

    const [linhas] = await pool.query(sql, params);
    res.json(linhas);
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  }
});

// ---------------------------------------------------------------------
// GET /api/alertas-sla?horas=24 - alertas para os gestores
// Chama a PROCEDURE sp_gerar_alertas_sla (IN p_horas, OUT p_qtd).
// O CALL e o SELECT @qtd precisam usar a MESMA conexão, porque a variável
// @qtd só existe dentro da sessão.
// ---------------------------------------------------------------------
app.get("/api/alertas-sla", async (req, res) => {
  const horas = Number(req.query.horas) || 24;
  const conexao = await pool.getConnection();
  try {
    const [resultado] = await conexao.query("CALL sp_gerar_alertas_sla(?, @qtd)", [horas]);
    const [[saida]] = await conexao.query("SELECT @qtd AS total");
    res.json({ total: saida.total, alertas: resultado[0] });
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  } finally {
    conexao.release();
  }
});

// ---------------------------------------------------------------------
// POST /api/tickets/:id/equipes  { equipeId, usuarioId }
// Pede apoio de outra equipe chamando a PROCEDURE sp_alocar_equipe_ticket.
// A mensagem de retorno vem do parâmetro OUT p_msg.
// ---------------------------------------------------------------------
app.post("/api/tickets/:id/equipes", async (req, res) => {
  const { equipeId, usuarioId } = req.body;
  if (!equipeId || !usuarioId) {
    return res.status(400).json({ erro: "Informe equipeId e usuarioId." });
  }
  const conexao = await pool.getConnection();
  try {
    await conexao.query("CALL sp_alocar_equipe_ticket(?, ?, ?, @msg)", [
      req.params.id,
      equipeId,
      usuarioId,
    ]);
    const [[saida]] = await conexao.query("SELECT @msg AS mensagem");
    const sucesso = saida.mensagem === "Equipe alocada com sucesso.";
    res.status(sucesso ? 200 : 422).json({ sucesso, mensagem: saida.mensagem });
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  } finally {
    conexao.release();
  }
});

// ---------------------------------------------------------------------
// GET /api/tickets/:id/equipes - equipes já alocadas no ticket
// ---------------------------------------------------------------------
app.get("/api/tickets/:id/equipes", async (req, res) => {
  try {
    const [linhas] = await pool.query(
      `SELECT e.id, e.nome
         FROM ticket_equipes te
        INNER JOIN equipes e ON e.id = te.equipe_id
        WHERE te.ticket_id = ?`,
      [req.params.id]
    );
    res.json(linhas);
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  }
});

// ---------------------------------------------------------------------
// GET /api/tickets/:id/historico - linha do tempo do ticket
// (mostra o evento EQUIPE_ALOCADA gravado pelo trigger)
// ---------------------------------------------------------------------
app.get("/api/tickets/:id/historico", async (req, res) => {
  try {
    const [linhas] = await pool.query(
      `SELECT h.evento, h.descricao, h.criado_em, u.nome AS usuario
         FROM historico_ticket h
         LEFT JOIN usuarios u ON u.id = h.usuario_id
        WHERE h.ticket_id = ?
        ORDER BY h.criado_em DESC`,
      [req.params.id]
    );
    res.json(linhas);
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  }
});

const porta = Number(process.env.PORT || 3000);
app.listen(porta, () => {
  console.log(`Painel de SLA rodando em http://localhost:${porta}`);
});
