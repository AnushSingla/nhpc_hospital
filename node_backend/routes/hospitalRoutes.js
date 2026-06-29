const express = require('express');
const router = express.Router();
const hospitalController = require('../controllers/hospitalController');

router.get('/hospitals', hospitalController.getAllHospitals);

module.exports = router;