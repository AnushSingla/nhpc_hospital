const express = require('express');
const cors = require('cors');
require('dotenv').config();

const hospitalRoutes = require('./routes/hospitalRoutes');
const feedbackRoutes = require('./routes/feedbackRoutes'); // <-- fixed case

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/feedback', feedbackRoutes);
app.use('/api', hospitalRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});