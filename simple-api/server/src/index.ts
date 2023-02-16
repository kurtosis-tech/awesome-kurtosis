const apiPort = 8080;
const express = require('express');
const bodyParser = require("body-parser");
const cors = require('cors')
const app = express();

import {clustersJson, enclavesJson, logs, services} from './data/data'

const filter = (filters: any, data: { [x: string]: any; }) => {
    return data.filter((log: { [x: string]: any; }) => {
        let isValid = true;
        for (let key in filters) {
            isValid = isValid && log[key] == filters[key];
        }
        return isValid;
    });
}

const startApi = () => {
    app.use(bodyParser.json());
    app.use(cors())

    app.get('/health', (req: any, res: any) => {
        return res.json({"status": "healthy"});
    });

    app.get('/api/v1/clusters', (req: any, res: any) => {
        res.send(filter(req.query, clustersJson));
    });

    app.get('/api/v1/enclaves', (req: any, res: any) => {
        res.send(filter(req.query, enclavesJson));
    });

    app.get('/api/v1/services', (req: any, res: any) => {
        res.send(filter(req.query, services));
    });

    app.get('/api/v1/logs', (req: any, res: any) => {
        res.send(filter(req.query, logs));
    });

    app.listen(apiPort, () => {
        console.log(`Server listening on the port::${apiPort}`);
    });
}

startApi();
