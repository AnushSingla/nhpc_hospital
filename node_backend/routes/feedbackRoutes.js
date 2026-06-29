const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Example: Save feedback to your database
router.post('/', async (req, res) => {
  const { feedback } = req.body;
  if (!feedback) {
    return res.status(400).json({ message: 'Feedback is required' });
  }
try {
    // Insert feedback into the 'feedback' table
    await pool.query('INSERT INTO feedback (feedback) VALUES (?)', [feedback]);
    res.status(200).json({ message: 'Feedback received' });
  } catch (err) {
    console.error('MySQL error:', err);
    res.status(500).json({ message: 'Database error' });
  }
});
module.exports = router;