// server.js
const express = require('express');
const cors = require('cors');
const sqlDriver = require('msnodesqlv8'); // Используем msnodesqlv8 напрямую

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json()); // Для парсинга JSON-тела POST запросов

// Строка подключения для msnodesqlv8
const connectionString = "Driver={ODBC Driver 17 for SQL Server};Server=THINKPAD;Database=WholesaleDB;Trusted_Connection=Yes;Encrypt=yes;TrustServerCertificate=yes;";
console.log("Using direct msnodesqlv8 with connection string:", connectionString);

// Функция для выполнения запроса с использованием msnodesqlv8 напрямую
async function executeQueryDirect(query, params = []) {
    return new Promise((resolve, reject) => {
        console.log("Executing direct query:", query, "with params:", params);
        // Примечание: sqlDriver.query ожидает параметры как простой массив для '?' плейсхолдеров.
        // Убедитесь, что ваши params соответствуют этому.
        sqlDriver.query(connectionString, query, params, (err, rows, more) => {
            if (err) {
                console.error("Direct msnodesqlv8 query FAILED:", err);
                const error = new Error(err.message || 'Database query failed');
                error.sqlState = err.sqlState;
                error.code = err.code;
                error.originalError = err;
                return reject(error);
            }
            console.log("Direct msnodesqlv8 query SUCCEEDED. Rows returned:", rows ? rows.length : 'N/A', "More results:", more);
            resolve(rows || []); // Возвращаем пустой массив, если rows undefined (например, для EXEC без SELECT)
        });
    });
}

// --- Эндпоинты для получения данных ---

app.get('/api/tables', async (req, res) => {
    const query = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = 'dbo' AND TABLE_CATALOG='WholesaleDB'";
    try {
        const data = await executeQueryDirect(query);
        res.json(data.map(t => t.TABLE_NAME));
    } catch (error) {
        res.status(500).json({ message: 'Error fetching tables', errorDetail: error.message });
    }
});

app.get('/api/views', async (req, res) => {
    const query = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_CATALOG='WholesaleDB'";
    try {
        const data = await executeQueryDirect(query);
        res.json(data.map(v => v.TABLE_NAME));
    } catch (error) {
        res.status(500).json({ message: 'Error fetching views', errorDetail: error.message });
    }
});

app.get('/api/data/:objectName', async (req, res) => {
    const objectName = req.params.objectName;
    if (!/^[a-zA-Z0-9_]+$/.test(objectName)) {
        return res.status(400).json({ message: 'Invalid object name format.' });
    }
    const safeObjectName = objectName.replace(/\]/g, ']]');
    const query = `SELECT TOP 100 * FROM dbo.[${safeObjectName}]`;
    try {
        const data = await executeQueryDirect(query);
        res.json(data);
    } catch (error) {
        console.error(`Error fetching data from dbo.${objectName}:`, error);
        res.status(500).json({ message: `Error fetching data from dbo.${objectName}`, errorDetail: error.message });
    }
});

app.get('/api/customer/:customerId/orders', async (req, res) => {
    const customerId = parseInt(req.params.customerId);
    if (isNaN(customerId)) {
        return res.status(400).json({ message: 'Invalid Customer ID' });
    }
    const query = `SELECT * FROM dbo.fn_GetCustomerOrderHistory(?)`;
    try {
        const data = await executeQueryDirect(query, [customerId]);
        res.json(data);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching customer order history', errorDetail: error.message });
    }
});

app.get('/api/products/lowstock', async (req, res) => {
    let targetWarehouseID = req.query.warehouseId ? parseInt(req.query.warehouseId) : null;
    let alertThreshold = req.query.threshold ? parseFloat(req.query.threshold) : 100.00;

    if (targetWarehouseID !== null && isNaN(targetWarehouseID)) targetWarehouseID = null;
    if (isNaN(alertThreshold)) alertThreshold = 100.00;

    const query = 'EXEC dbo.sp_GetLowStockProducts ?, ?';
    const params = [targetWarehouseID, alertThreshold];
    try {
        const data = await executeQueryDirect(query, params);
        res.json(data);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching low stock products', errorDetail: error.message });
    }
});

// --- Эндпоинты для управления заказами ---

app.post('/api/orders', async (req, res) => {
    const { customerId, employeeId, requiredDeliveryDate, shippingAddress } = req.body;

    if (!customerId || !employeeId) {
        return res.status(400).json({ message: 'Customer ID and Employee ID are required.' });
    }
    if (isNaN(parseInt(customerId)) || isNaN(parseInt(employeeId))) {
        return res.status(400).json({ message: 'Customer ID and Employee ID must be numbers.' });
    }

    const query = 'EXEC dbo.sp_CreateNewOrder ?, ?, ?, ?';
    const params = [
        parseInt(customerId),
        parseInt(employeeId),
        requiredDeliveryDate || null,
        shippingAddress || null
    ];

    try {
        const result = await executeQueryDirect(query, params);
        let newOrderId = null;
        if (result && result.length > 0 && result[0]) {
            // sp_CreateNewOrder возвращает SELECT SCOPE_IDENTITY() AS NewOrderID;
            // или просто SCOPE_IDENTITY() - имя колонки может быть пустым ("") или "NewOrderID"
            const firstRow = result[0];
            const keys = Object.keys(firstRow);
            if (keys.length > 0) newOrderId = firstRow[keys[0]];
        }

        if (newOrderId !== null) {
            res.status(201).json({ orderId: newOrderId, message: 'Order created successfully.' });
        } else {
            console.warn("sp_CreateNewOrder may have executed, but OrderID was not retrieved from result:", result);
            res.status(200).json({ message: 'Order creation initiated, but Order ID was not returned by SP. Check SP logic or DB logs.' });
        }
    } catch (error) {
        console.error('Error creating order:', error);
        res.status(500).json({ 
            message: error.message || 'Failed to create order.', 
            errorDetail: error.originalError ? error.originalError.message : 'Database error.' 
        });
    }
});

app.post('/api/orders/:orderId/items', async (req, res) => {
    const orderId = parseInt(req.params.orderId);
    const { productId, warehouseId, quantity } = req.body;

    if (isNaN(orderId)) {
        return res.status(400).json({ message: 'Order ID in URL must be a number.' });
    }
    if (productId === undefined || warehouseId === undefined || quantity === undefined) {
        return res.status(400).json({ message: 'Product ID, Warehouse ID, and Quantity are required.' });
    }
    const numProductId = parseInt(productId);
    const numWarehouseId = parseInt(warehouseId);
    const numQuantity = parseInt(quantity);

    if (isNaN(numProductId) || isNaN(numWarehouseId) || isNaN(numQuantity)) {
        return res.status(400).json({ message: 'Product ID, Warehouse ID, and Quantity must be numbers.' });
    }
    if (numQuantity <= 0) {
        return res.status(400).json({ message: 'Quantity must be greater than zero.' });
    }

    const query = 'EXEC dbo.sp_AddProductToOrder ?, ?, ?, ?';
    const params = [orderId, numProductId, numWarehouseId, numQuantity];

    try {
        // sp_AddProductToOrder использует PRINT и RAISERROR.
        // Если RAISERROR не сработал, считаем успехом.
        await executeQueryDirect(query, params);
        res.status(200).json({ message: 'Товар успешно добавлен/обновлен в заказе.' });
    } catch (error) {
        console.error('Error adding item to order:', error);
        // Сообщение из RAISERROR должно быть в error.message
        res.status(500).json({ 
            message: error.message || 'Failed to add item to order.',
            errorDetail: error.originalError ? error.originalError.message : 'Database error.'
        });
    }
});


app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});