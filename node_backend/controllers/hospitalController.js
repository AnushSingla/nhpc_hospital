const pool = require('../config/db');

exports.getAllHospitals = async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM hospitals');
    res.json(rows);
  } catch (err) {
    console.error('MySQL error:', err);
    res.status(500).json({ message: 'Database error' });
  }
};