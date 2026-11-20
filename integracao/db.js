// Conexão com o banco da AV3 (altave_av3) - isolado do banco da API do time.
const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "altave_av3",
  dateStrings: true, // datas chegam como texto "AAAA-MM-DD hh:mm:ss"
  connectionLimit: 5,
});

module.exports = pool;
