const mysql = require('mysql2/promise');
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});
pool.getConnection()
  .then(conn => {
    console.log('MySQL connected!');
    conn.release();
  })
  .catch(err => {
    console.error('MySQL connection error:', err);
  });

module.exports = pool;