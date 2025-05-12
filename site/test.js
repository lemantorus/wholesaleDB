// test_msnodesqlv8.js
const sql = require('msnodesqlv8');

const connectionString = "server=THINKPAD;Database=WholesaleDB;Trusted_Connection=Yes;Driver={ODBC Driver 17 for SQL Server}";
// Примечание: {ODBC Driver 17 for SQL Server} - это обычный драйвер. Вы можете проверить, какой у вас установлен
// через "ODBC Data Sources (64-bit)" в Windows -> Drivers. Может быть {SQL Server Native Client 11.0} или просто {SQL Server}.
// {ODBC Driver 18 for SQL Server} тоже популярен.

console.log("Attempting to connect directly with msnodesqlv8...");
console.log("Connection string:", connectionString);

sql.query(connectionString, "SELECT GETDATE() AS CurrentTime", (err, rows) => {
    if (err) {
        console.error("Direct msnodesqlv8 connection FAILED:", err);
        return;
    }
    console.log("Direct msnodesqlv8 connection SUCCESSFUL!");
    console.log("CurrentTime from DB:", rows);
});