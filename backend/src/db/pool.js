const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "Pasindu@22",
  database: process.env.DB_NAME || "food_rush",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

async function dbHealthCheck() {
  const [rows] = await pool.query("SELECT 1 AS ok");
  return rows?.[0]?.ok === 1;
}

module.exports = {
  pool,
  dbHealthCheck
};

