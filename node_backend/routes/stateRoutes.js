const express = require('express');
const router = express.Router();
const stateController = require('../controllers/stateController');
router.get('/states', stateController.getStates);
module.exports = router;