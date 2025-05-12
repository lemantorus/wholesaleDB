-- 0. Создание и использование базы данных
IF DB_ID('WholesaleDB') IS NULL
BEGIN
    CREATE DATABASE WholesaleDB;
END
GO

USE WholesaleDB;
GO

-- 1. Создание таблиц (DDL)

-- Категории товаров
CREATE TABLE Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(255) NULL
);
GO

-- Поставщики
CREATE TABLE Suppliers (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName NVARCHAR(150) NOT NULL,
    ContactName NVARCHAR(100) NULL,
    Phone VARCHAR(20) NULL,
    Email VARCHAR(100) NULL UNIQUE CHECK (Email IS NULL OR Email LIKE '%@%.%'),
    Address NVARCHAR(255) NULL,
    RegistrationDate DATE NOT NULL DEFAULT GETDATE()
);
GO

-- Товары
CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(150) NOT NULL,
    CategoryID INT NOT NULL,
    SupplierID INT NOT NULL,
    UnitOfMeasure NVARCHAR(20) NOT NULL DEFAULT 'шт.',
    PurchasePrice DECIMAL(10,2) NOT NULL CHECK (PurchasePrice >= 0),
    SellingPrice DECIMAL(10,2) NOT NULL CHECK (SellingPrice >= 0),
    Description NVARCHAR(MAX) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    CONSTRAINT FK_Products_Suppliers FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID),
    CONSTRAINT CK_ProductPrices CHECK (SellingPrice >= PurchasePrice)
);
GO

-- Склады
CREATE TABLE Warehouses (
    WarehouseID INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseName NVARCHAR(100) NOT NULL UNIQUE,
    Location NVARCHAR(255) NULL,
    Capacity INT NULL CHECK (Capacity IS NULL OR Capacity > 0)
);
GO

-- Остатки на складе
CREATE TABLE WarehouseStock (
    StockID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    WarehouseID INT NOT NULL,
    QuantityOnHand INT NOT NULL DEFAULT 0 CHECK (QuantityOnHand >= 0),
    MinStockLevel INT NULL DEFAULT 10 CHECK (MinStockLevel IS NULL OR MinStockLevel >= 0),
    MaxStockLevel INT NULL DEFAULT 100, -- CHECK (MaxStockLevel IS NULL OR MaxStockLevel >= MinStockLevel), -- Перенесено в ограничение таблицы
    LastStockUpdate DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_WarehouseStock_Products FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    CONSTRAINT FK_WarehouseStock_Warehouses FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID),
    CONSTRAINT UQ_ProductWarehouse UNIQUE (ProductID, WarehouseID),
    CONSTRAINT CK_WarehouseStock_MaxLevel CHECK (MaxStockLevel IS NULL OR MaxStockLevel >= MinStockLevel) -- Исправлено: ограничение на уровне таблицы
);
GO

-- Должности сотрудников
CREATE TABLE Positions (
    PositionID INT IDENTITY(1,1) PRIMARY KEY,
    PositionName NVARCHAR(100) NOT NULL UNIQUE,
    BaseSalary DECIMAL(10,2) NULL CHECK (BaseSalary IS NULL OR BaseSalary > 0)
);
GO

-- Сотрудники
CREATE TABLE Employees (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    PositionID INT NOT NULL,
    HireDate DATE NOT NULL,
    BirthDate DATE NULL,
    Phone VARCHAR(20) NULL,
    Email VARCHAR(100) NULL UNIQUE CHECK (Email IS NULL OR Email LIKE '%@%.%'),
    Address NVARCHAR(255) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Employees_Positions FOREIGN KEY (PositionID) REFERENCES Positions(PositionID)
);
GO

-- Клиенты/Заказчики
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName NVARCHAR(150) NOT NULL,
    ContactName NVARCHAR(100) NULL,
    Phone VARCHAR(20) NULL,
    Email VARCHAR(100) NULL UNIQUE CHECK (Email IS NULL OR Email LIKE '%@%.%'),
    Address NVARCHAR(255) NULL,
    RegistrationDate DATE NOT NULL DEFAULT GETDATE(),
    DiscountPercentage DECIMAL(5,2) NOT NULL DEFAULT 0.00 CHECK (DiscountPercentage BETWEEN 0.00 AND 100.00)
);
GO

-- Заказы
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
    RequiredDeliveryDate DATE NULL,
    ShippedDate DATETIME NULL,
    OrderStatus NVARCHAR(50) NOT NULL DEFAULT 'Pending'
        CHECK (OrderStatus IN ('Pending', 'Processing', 'AwaitingPayment', 'Shipped', 'Delivered', 'Cancelled')),
    ShippingAddress NVARCHAR(255) NULL,
    TotalAmount DECIMAL(12,2) NULL DEFAULT 0.00,
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Orders_Employees FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);
GO

-- Детали заказа
CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    WarehouseID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    Discount DECIMAL(5,2) NOT NULL DEFAULT 0.00 CHECK (Discount BETWEEN 0.00 AND 100.00),
    LineTotal AS (CONVERT(DECIMAL(12,2), Quantity * UnitPrice * (1 - Discount/100.0))) PERSISTED,
    CONSTRAINT FK_OrderDetails_Orders FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    CONSTRAINT FK_OrderDetails_Products FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    CONSTRAINT FK_OrderDetails_Warehouses FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID),
    CONSTRAINT UQ_OrderDetailProduct UNIQUE (OrderID, ProductID)
);
GO

-- Способы оплаты
CREATE TABLE PaymentMethods (
    PaymentMethodID INT IDENTITY(1,1) PRIMARY KEY,
    MethodName NVARCHAR(50) NOT NULL UNIQUE
);
GO

-- Платежи
CREATE TABLE Payments (
    PaymentID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    PaymentMethodID INT NOT NULL,
    PaymentDate DATETIME NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(12,2) NOT NULL CHECK (Amount > 0),
    TransactionReference NVARCHAR(100) NULL,
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_Payments_PaymentMethods FOREIGN KEY (PaymentMethodID) REFERENCES PaymentMethods(PaymentMethodID)
);
GO

-- 2. Вставка начальных данных (DML)
-- (Данные остаются без изменений, предполагается, что ошибки были только в DDL или объектах)
-- Категории
INSERT INTO Categories (CategoryName, Description) VALUES
('Электроника', 'Бытовая и цифровая электроника'),
('Продукты питания', 'Бакалея, напитки, консервы'),
('Одежда', 'Мужская, женская и детская одежда'),
('Канцтовары', 'Товары для офиса и школы'),
('Строительные материалы', 'Материалы для ремонта и строительства');
GO
-- Поставщики
INSERT INTO Suppliers (SupplierName, ContactName, Phone, Email, Address, RegistrationDate) VALUES
('ООО "ТехноМир"', 'Иванов Петр', '8-800-555-3535', 'info@technomir.com', 'г. Москва, ул. Ленина, 10', '2021-01-15'),
('ЗАО "Провиант"', 'Сидорова Анна', '8-495-123-4567', 'sales@proviant.ru', 'г. Санкт-Петербург, пр. Невский, 20', '2020-06-20'),
('ИП "Модный Дом"', 'Кузнецов Олег', '8-916-777-8899', 'fashion@mail.com', 'г. Екатеринбург, ул. Мира, 5', '2022-03-10'),
('ООО "СтройКом"', 'Васильев Игорь', '8-343-555-0011', 'stroy@com.org', 'г. Новосибирск, ул. Промышленная, 15', '2019-11-01');
GO
-- Товары
INSERT INTO Products (ProductName, CategoryID, SupplierID, UnitOfMeasure, PurchasePrice, SellingPrice, Description, IsActive) VALUES
('Смартфон Galaxy S23', 1, 1, 'шт.', 50000.00, 65000.00, 'Флагманский смартфон с AMOLED экраном', 1),
('Ноутбук IdeaPad 5', 1, 1, 'шт.', 60000.00, 78000.00, 'Производительный ноутбук для работы и учебы', 1),
('Кофе молотый "Арабика"', 2, 2, 'кг', 500.00, 750.00, '100% Арабика, средняя обжарка', 1),
('Макароны "Экстра"', 2, 2, 'пачка', 50.00, 70.00, 'Макаронные изделия из твердых сортов пшеницы', 1),
('Джинсы мужские Classic', 3, 3, 'шт.', 2500.00, 3500.00, 'Классические синие джинсы', 1),
('Платье женское "Лето"', 3, 3, 'шт.', 1800.00, 2800.00, 'Легкое летнее платье из хлопка', 0),
('Ручка шариковая синяя', 4, 1, 'шт.', 10.00, 15.00, 'Стандартная шариковая ручка, синие чернила', 1),
('Цемент М500 (25кг)', 5, 4, 'мешок', 300.00, 400.00, 'Портландцемент марки 500, мешок 25 кг', 1),
('Телевизор QLED 55"', 1, 1, 'шт.', 70000.00, 95000.00, 'Телевизор с квантовыми точками, 55 дюймов', 1),
('Чай черный цейлонский', 2, 2, 'пачка', 150.00, 220.00, 'Крупнолистовой черный чай', 1);
GO
-- Склады
INSERT INTO Warehouses (WarehouseName, Location, Capacity) VALUES
('Основной склад', 'г. Москва, Южный порт, стр. 5', 10000),
('Склад №2 (Холодильный)', 'г. Москва, ул. Морозильная, 1', 500),
('Региональный склад (СПБ)', 'г. Санкт-Петербург, ул. Складская, 3', 3000);
GO
-- Остатки на складе
INSERT INTO WarehouseStock (ProductID, WarehouseID, QuantityOnHand, MinStockLevel, MaxStockLevel) VALUES
(1, 1, 50, 10, 100),
(2, 1, 30, 15, 80),
(3, 2, 200, 50, 500),
(4, 1, 500, 100, 1000),
(5, 1, 120, 20, 200),
(7, 1, 1000, 200, 5000),
(8, 3, 80, 20, 150),
(9, 1, 5, 3, 20),
(10, 2, 150, 30, 300);
GO
-- Должности
INSERT INTO Positions (PositionName, BaseSalary) VALUES
('Менеджер по продажам', 60000.00),
('Кладовщик', 40000.00),
('Бухгалтер', 70000.00),
('Директор', 150000.00);
GO
-- Сотрудники
INSERT INTO Employees (FirstName, LastName, PositionID, HireDate, BirthDate, Phone, Email, Address) VALUES
('Алексей', 'Петров', 1, '2022-05-10', '1990-03-15', '8-926-111-2233', 'a.petrov@wholesaledb.com', 'г. Москва, ул. Центральная, 1'),
('Мария', 'Иванова', 1, '2023-01-20', '1995-07-22', '8-916-222-3344', 'm.ivanova@wholesaledb.com', 'г. Москва, ул. Парковая, 5'),
('Иван', 'Сидоров', 2, '2021-11-01', '1985-12-01', '8-903-333-4455', 'i.sidorov@wholesaledb.com', 'г. Москва, ул. Складская, 10'),
('Елена', 'Васильева', 3, '2020-08-15', '1988-02-10', '8-965-444-5566', 'e.vasileva@wholesaledb.com', 'г. Москва, ул. Финансовая, 3'),
('Сергей', 'Кузнецов', 4, '2019-01-10', '1975-09-05', '8-905-555-6677', 's.kuznetsov@wholesaledb.com', 'г. Москва, ул. Главная, 100');
GO
-- Клиенты
INSERT INTO Customers (CustomerName, ContactName, Phone, Email, Address, DiscountPercentage) VALUES
('ООО "Ромашка"', 'Ольга Сергеева', '8-499-001-0001', 'romashka@llc.com', 'г. Москва, ул. Цветочная, 7', 5.00),
('ИП "БытСервис"', 'Андрей Новиков', '8-495-002-0002', 'bitservis@ip.ru', 'г. Люберцы, ул. Новая, 12', 0.00),
('АО "МегаСтрой"', 'Дмитрий Воронов', '8-800-200-0003', 'megastroy@ao.org', 'г. Москва, Проспект Вернадского, 41', 10.00),
('ООО "Электрошоп"', 'Константин Белов', '8-499-004-0004', 'electroshop@contact.com', 'г. Химки, ул. Электронная, 1', 2.50);
GO
-- Способы оплаты
INSERT INTO PaymentMethods (MethodName) VALUES
('Наличные'),
('Банковская карта'),
('Безналичный расчет (юр. лица)');
GO
-- Заказы
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, RequiredDeliveryDate, ShippedDate, OrderStatus, ShippingAddress, TotalAmount) VALUES
(1, 1, '2023-10-01 10:00:00', '2023-10-05', '2023-10-02 15:00:00', 'Shipped', 'г. Москва, ул. Цветочная, 7', 0),
(2, 2, '2023-10-05 11:30:00', '2023-10-10', NULL, 'Processing', 'г. Люберцы, ул. Новая, 12', 0),
(3, 1, '2023-10-08 14:00:00', '2023-10-12', NULL, 'Pending', 'г. Москва, Проспект Вернадского, 41', 0),
(1, 2, '2023-10-10 09:15:00', '2023-10-15', NULL, 'AwaitingPayment', 'г. Москва, ул. Цветочная, 7', 0),
(4, 1, '2023-11-01 16:00:00', '2023-11-05', '2023-11-02 12:00:00', 'Delivered', 'г. Химки, ул. Электронная, 1', 0);
GO
-- Детали заказа
INSERT INTO OrderDetails (OrderID, ProductID, WarehouseID, Quantity, UnitPrice, Discount) VALUES
(1, 3, 2, 10, 750.00, 5.00),
(1, 4, 1, 20, 70.00, 5.00);
INSERT INTO OrderDetails (OrderID, ProductID, WarehouseID, Quantity, UnitPrice, Discount) VALUES
(2, 1, 1, 1, 65000.00, 0.00),
(2, 7, 1, 50, 15.00, 0.00);
INSERT INTO OrderDetails (OrderID, ProductID, WarehouseID, Quantity, UnitPrice, Discount) VALUES
(3, 8, 3, 10, 400.00, 10.00);
INSERT INTO OrderDetails (OrderID, ProductID, WarehouseID, Quantity, UnitPrice, Discount) VALUES
(4, 10, 2, 5, 220.00, 5.00);
INSERT INTO OrderDetails (OrderID, ProductID, WarehouseID, Quantity, UnitPrice, Discount) VALUES
(5, 9, 1, 2, 95000.00, 2.50);
GO
-- Платежи
INSERT INTO Payments (OrderID, PaymentMethodID, PaymentDate, Amount, TransactionReference) VALUES
(1, 2, '2023-10-01 10:05:00', (SELECT SUM(od.Quantity * od.UnitPrice * (1 - od.Discount/100.0)) FROM OrderDetails od WHERE od.OrderID = 1), 'TRX1001CARD'), -- Исправлено: Явный расчет суммы, так как LineTotal - вычисляемое поле
(5, 3, '2023-11-01 16:10:00', (SELECT SUM(od.Quantity * od.UnitPrice * (1 - od.Discount/100.0)) FROM OrderDetails od WHERE od.OrderID = 5), 'INV-2023-11-01/1'); -- Исправлено
GO


-- 3. Создание таблицы аудита для сотрудников
CREATE TABLE EmployeeAuditLog (
    AuditLogID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    ChangedColumn NVARCHAR(100) NOT NULL,
    OldValue NVARCHAR(MAX) NULL,
    NewValue NVARCHAR(MAX) NULL,
    ChangeDate DATETIME NOT NULL DEFAULT GETDATE(),
    ChangedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
    CONSTRAINT FK_EmployeeAuditLog_Employees FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID) ON DELETE CASCADE
);
GO

-- 4. Создание пользовательских функций (UDF)

CREATE FUNCTION fn_GetProductCurrentStock (@ProductID INT)
RETURNS INT
AS
BEGIN
    DECLARE @TotalStock INT;
    SELECT @TotalStock = ISNULL(SUM(QuantityOnHand), 0)
    FROM WarehouseStock
    WHERE ProductID = @ProductID;
    RETURN @TotalStock;
END;
GO

CREATE FUNCTION fn_CalculateOrderTotalAmount (@OrderID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @TotalAmount DECIMAL(12,2);
    SELECT @TotalAmount = ISNULL(SUM(LineTotal), 0.00)
    FROM OrderDetails
    WHERE OrderID = @OrderID;
    RETURN @TotalAmount;
END;
GO

CREATE FUNCTION fn_GetCustomerOrderHistory (@CustomerID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        o.OrderID,
        o.OrderDate,
        o.OrderStatus,
        o.TotalAmount,
        e.FirstName + ' ' + e.LastName AS EmployeeFullName
    FROM Orders o
    JOIN Employees e ON o.EmployeeID = e.EmployeeID
    WHERE o.CustomerID = @CustomerID
);
GO

-- 5. Создание представлений (Views)
CREATE VIEW v_ActiveProducts
AS
SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    s.SupplierName,
    p.SellingPrice,
    p.UnitOfMeasure,
    dbo.fn_GetProductCurrentStock(p.ProductID) AS TotalStock
FROM Products p
JOIN Categories c ON p.CategoryID = c.CategoryID
JOIN Suppliers s ON p.SupplierID = s.SupplierID
WHERE p.IsActive = 1;
GO

CREATE VIEW v_CustomerContactInfo
AS
SELECT
    CustomerID,
    CustomerName,
    ContactName,
    Phone,
    Email,
    Address,
    DiscountPercentage
FROM Customers;
GO

CREATE VIEW v_EmployeeDirectory
AS
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS FullName,
    pos.PositionName, -- Изменил алиас таблицы Positions
    e.Email,
    e.Phone,
    e.HireDate,
    e.IsActive
FROM Employees e
JOIN Positions pos ON e.PositionID = pos.PositionID; -- Изменил алиас таблицы Positions
GO

CREATE VIEW v_PendingOrders
AS
SELECT
    o.OrderID,
    c.CustomerName,
    o.OrderDate,
    o.OrderStatus,
    o.RequiredDeliveryDate,
    o.TotalAmount,
    e.FirstName + ' ' + e.LastName AS ResponsibleEmployee
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Employees e ON o.EmployeeID = e.EmployeeID
WHERE o.OrderStatus IN ('Pending', 'Processing', 'AwaitingPayment');
GO

CREATE VIEW v_ProductStockSummary
AS
SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    ISNULL(SUM(ws.QuantityOnHand), 0) AS TotalQuantityOnHand
FROM Products p
LEFT JOIN WarehouseStock ws ON p.ProductID = ws.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY p.ProductID, p.ProductName, c.CategoryName;
GO

CREATE VIEW v_DetailedOrderInformation
AS
SELECT
    o.OrderID,
    o.OrderDate,
    c.CustomerName,
    cust_cont.Phone AS CustomerPhone,
    e.FirstName + ' ' + e.LastName AS EmployeeFullName,
    o.OrderStatus,
    o.RequiredDeliveryDate,
    o.ShippedDate,
    o.ShippingAddress,
    o.TotalAmount
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
LEFT JOIN v_CustomerContactInfo cust_cont ON o.CustomerID = cust_cont.CustomerID
JOIN Employees e ON o.EmployeeID = e.EmployeeID;
GO

CREATE VIEW v_ProductSalesPerformance
AS
SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    ISNULL(SUM(od.Quantity), 0) AS TotalQuantitySold,
    ISNULL(SUM(od.LineTotal), 0.00) AS TotalRevenue
FROM Products p
LEFT JOIN OrderDetails od ON p.ProductID = od.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY p.ProductID, p.ProductName, c.CategoryName;
GO

CREATE VIEW v_SupplierProductList
AS
SELECT
    s.SupplierID,
    s.SupplierName,
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    p.PurchasePrice,
    p.SellingPrice,
    p.IsActive
FROM Suppliers s
JOIN Products p ON s.SupplierID = p.SupplierID
JOIN Categories c ON p.CategoryID = c.CategoryID;
GO


-- 6. Создание хранимых процедур (Stored Procedures)
CREATE PROCEDURE sp_CreateNewOrder (
    @CustomerID INT,
    @EmployeeID INT,
    @RequiredDeliveryDate DATE = NULL,
    @ShippingAddress NVARCHAR(255) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID = @CustomerID)
    BEGIN
        RAISERROR('Клиент с ID %d не найден.', 16, 1, @CustomerID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @EmployeeID AND IsActive = 1)
    BEGIN
        RAISERROR('Сотрудник с ID %d не найден или неактивен.', 16, 1, @EmployeeID);
        RETURN;
    END

    DECLARE @ActualShippingAddress NVARCHAR(255);
    IF @ShippingAddress IS NULL
    BEGIN
        SELECT @ActualShippingAddress = Address FROM Customers WHERE CustomerID = @CustomerID;
    END
    ELSE
    BEGIN
        SET @ActualShippingAddress = @ShippingAddress;
    END

    INSERT INTO Orders (CustomerID, EmployeeID, RequiredDeliveryDate, ShippingAddress, OrderStatus, TotalAmount)
    VALUES (@CustomerID, @EmployeeID, @RequiredDeliveryDate, @ActualShippingAddress, 'Pending', 0.00);

    SELECT SCOPE_IDENTITY() AS NewOrderID;
END;
GO

CREATE PROCEDURE sp_AddProductToOrder (
    @OrderID INT,
    @ProductID INT,
    @WarehouseID INT,
    @Quantity INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = @OrderID AND OrderStatus IN ('Pending', 'AwaitingPayment', 'Processing'))
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Заказ с ID %d не найден или его нельзя редактировать.', 16, 1, @OrderID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Products WHERE ProductID = @ProductID AND IsActive = 1)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Товар с ID %d не найден или неактивен.', 16, 1, @ProductID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Warehouses WHERE WarehouseID = @WarehouseID)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Склад с ID %d не найден.', 16, 1, @WarehouseID);
        RETURN;
    END

    DECLARE @CurrentStock INT;
    SELECT @CurrentStock = QuantityOnHand FROM WarehouseStock WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;

    IF @CurrentStock IS NULL OR @CurrentStock < @Quantity
    BEGIN
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(512); -- Исправлено
        SET @ErrorMessage = FORMATMESSAGE('Недостаточно товара (ID: %d) на складе (ID: %d). Доступно: %d, Запрошено: %d.', @ProductID, @WarehouseID, ISNULL(@CurrentStock,0), @Quantity); -- Исправлено
        RAISERROR(@ErrorMessage, 16, 1); -- Исправлено
        RETURN;
    END

    DECLARE @SellingPrice DECIMAL(10,2);
    DECLARE @CustomerDiscount DECIMAL(5,2);
    DECLARE @FinalDiscount DECIMAL(5,2);

    SELECT @SellingPrice = SellingPrice FROM Products WHERE ProductID = @ProductID;
    SELECT @CustomerDiscount = c.DiscountPercentage
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
    WHERE o.OrderID = @OrderID;

    SET @FinalDiscount = @CustomerDiscount;

    IF EXISTS (SELECT 1 FROM OrderDetails WHERE OrderID = @OrderID AND ProductID = @ProductID)
    BEGIN
        UPDATE OrderDetails
        SET Quantity = Quantity + @Quantity
        WHERE OrderID = @OrderID AND ProductID = @ProductID;
    END
    ELSE
    BEGIN
        INSERT INTO OrderDetails (OrderID, ProductID, WarehouseID, Quantity, UnitPrice, Discount)
        VALUES (@OrderID, @ProductID, @WarehouseID, @Quantity, @SellingPrice, @FinalDiscount);
    END
    COMMIT TRANSACTION;
    PRINT 'Товар успешно добавлен/обновлен в заказе.';
END;
GO

CREATE PROCEDURE sp_UpdateOrderStatus (
    @OrderID INT,
    @NewOrderStatus NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = @OrderID)
    BEGIN
        RAISERROR('Заказ с ID %d не найден.', 16, 1, @OrderID);
        RETURN;
    END

    IF @NewOrderStatus NOT IN ('Pending', 'Processing', 'AwaitingPayment', 'Shipped', 'Delivered', 'Cancelled')
    BEGIN
        RAISERROR('Недопустимый статус заказа: %s.', 16, 1, @NewOrderStatus);
        RETURN;
    END

    UPDATE Orders
    SET OrderStatus = @NewOrderStatus,
        ShippedDate = CASE
                        WHEN @NewOrderStatus = 'Shipped' AND ShippedDate IS NULL THEN GETDATE()
                        ELSE ShippedDate
                      END
    WHERE OrderID = @OrderID;

    PRINT 'Статус заказа обновлен.';
END;
GO

CREATE PROCEDURE sp_ProcessPaymentForOrder (
    @OrderID INT,
    @PaymentMethodID INT,
    @AmountPaid DECIMAL(12,2),
    @TransactionReference NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = @OrderID)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Заказ с ID %d не найден.', 16, 1, @OrderID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM PaymentMethods WHERE PaymentMethodID = @PaymentMethodID)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Способ оплаты с ID %d не найден.', 16, 1, @PaymentMethodID);
        RETURN;
    END

    IF @AmountPaid <= 0
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Сумма платежа должна быть больше нуля.', 16, 1);
        RETURN;
    END

    INSERT INTO Payments (OrderID, PaymentMethodID, Amount, TransactionReference, PaymentDate)
    VALUES (@OrderID, @PaymentMethodID, @AmountPaid, @TransactionReference, GETDATE());

    DECLARE @TotalOrderAmount DECIMAL(12,2);
    DECLARE @TotalPaidAmount DECIMAL(12,2);
    DECLARE @CurrentOrderStatus NVARCHAR(50);

    SELECT @TotalOrderAmount = TotalAmount, @CurrentOrderStatus = OrderStatus FROM Orders WHERE OrderID = @OrderID;
    SELECT @TotalPaidAmount = ISNULL(SUM(Amount),0) FROM Payments WHERE OrderID = @OrderID;

    IF @CurrentOrderStatus = 'AwaitingPayment' AND @TotalPaidAmount >= @TotalOrderAmount
    BEGIN
        UPDATE Orders SET OrderStatus = 'Processing' WHERE OrderID = @OrderID;
        PRINT 'Платеж зарегистрирован. Статус заказа изменен на "Processing".';
    END
    ELSE
    BEGIN
         PRINT 'Платеж зарегистрирован.';
    END

    COMMIT TRANSACTION;
END;
GO

CREATE PROCEDURE sp_GetLowStockProducts (
    @TargetWarehouseID INT = NULL,
    @AlertThresholdPercentage DECIMAL(5,2) = 100.00
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProductID_Cur INT; -- Изменил имена переменных курсора, чтобы избежать конфликтов
    DECLARE @ProductName_Cur NVARCHAR(150);
    DECLARE @WarehouseID_Cur INT;
    DECLARE @WarehouseName_Cur NVARCHAR(100);
    DECLARE @QuantityOnHand_Cur INT;
    DECLARE @MinStockLevel_Cur INT;
    DECLARE @CalculatedMinStock_Cur DECIMAL(10,2);
    DECLARE @CalculatedMinStockStr_Cur NVARCHAR(20); -- Для вывода в FORMATMESSAGE

    PRINT 'Отчет по товарам с низким уровнем запасов (ниже или равно ' + CONVERT(VARCHAR(10), @AlertThresholdPercentage) + '% от минимального уровня):';
    PRINT '------------------------------------------------------------------------------------------'; -- Увеличил ширину
    PRINT 'ID Товара | Название товара          | ID Склада | Название склада   | В наличии | Мин. уровень | Порог (расч.)';
    PRINT '------------------------------------------------------------------------------------------';

    DECLARE LowStockCursor CURSOR LOCAL FAST_FORWARD FOR -- Добавил LOCAL FAST_FORWARD для оптимизации
        SELECT
            p.ProductID,
            p.ProductName,
            ws.WarehouseID,
            w.WarehouseName,
            ws.QuantityOnHand,
            ws.MinStockLevel
        FROM WarehouseStock ws
        JOIN Products p ON ws.ProductID = p.ProductID
        JOIN Warehouses w ON ws.WarehouseID = w.WarehouseID
        WHERE (@TargetWarehouseID IS NULL OR ws.WarehouseID = @TargetWarehouseID)
          AND ws.MinStockLevel IS NOT NULL AND ws.MinStockLevel > 0;

    OPEN LowStockCursor;
    FETCH NEXT FROM LowStockCursor INTO @ProductID_Cur, @ProductName_Cur, @WarehouseID_Cur, @WarehouseName_Cur, @QuantityOnHand_Cur, @MinStockLevel_Cur;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @CalculatedMinStock_Cur = @MinStockLevel_Cur * (@AlertThresholdPercentage / 100.0);
        IF @QuantityOnHand_Cur <= @CalculatedMinStock_Cur
        BEGIN
            SET @CalculatedMinStockStr_Cur = CONVERT(NVARCHAR(20), @CalculatedMinStock_Cur, 1); -- Стиль 1 для decimal: 123.45
            PRINT
                FORMATMESSAGE('%-10d | %-24s | %-9d | %-17s | %-9d | %-12d | %s', -- Скорректировал ширину полей
                @ProductID_Cur,
                LEFT(@ProductName_Cur, 24),
                @WarehouseID_Cur,
                LEFT(@WarehouseName_Cur,17),
                @QuantityOnHand_Cur,
                @MinStockLevel_Cur,
                @CalculatedMinStockStr_Cur); -- Исправлено: передача строки
        END
        FETCH NEXT FROM LowStockCursor INTO @ProductID_Cur, @ProductName_Cur, @WarehouseID_Cur, @WarehouseName_Cur, @QuantityOnHand_Cur, @MinStockLevel_Cur;
    END

    CLOSE LowStockCursor;
    DEALLOCATE LowStockCursor;
    PRINT '------------------------------------------------------------------------------------------';
    PRINT 'Отчет завершен.';
END;
GO


-- 7. Создание триггеров (Triggers)
CREATE TRIGGER trg_UpdateStockOnOrderDetailInsertDelete
ON OrderDetails
AFTER INSERT, DELETE, UPDATE -- Добавил UPDATE для корректной обработки изменения Quantity
AS
BEGIN
    SET NOCOUNT ON;

    -- Обработка INSERT
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
    BEGIN
        UPDATE ws
        SET ws.QuantityOnHand = ws.QuantityOnHand - i.Quantity,
            ws.LastStockUpdate = GETDATE()
        FROM WarehouseStock ws
        JOIN inserted i ON ws.ProductID = i.ProductID AND ws.WarehouseID = i.WarehouseID;
    END

    -- Обработка DELETE
    IF EXISTS (SELECT * FROM deleted) AND NOT EXISTS (SELECT * FROM inserted)
    BEGIN
        UPDATE ws
        SET ws.QuantityOnHand = ws.QuantityOnHand + d.Quantity,
            ws.LastStockUpdate = GETDATE()
        FROM WarehouseStock ws
        JOIN deleted d ON ws.ProductID = d.ProductID AND ws.WarehouseID = d.WarehouseID;
    END

    -- Обработка UPDATE (изменение Quantity или WarehouseID)
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        -- Возвращаем старое количество на старый склад
        UPDATE ws
        SET ws.QuantityOnHand = ws.QuantityOnHand + d.Quantity,
            ws.LastStockUpdate = GETDATE()
        FROM WarehouseStock ws
        JOIN deleted d ON ws.ProductID = d.ProductID AND ws.WarehouseID = d.WarehouseID;

        -- Вычитаем новое количество с нового склада
        UPDATE ws
        SET ws.QuantityOnHand = ws.QuantityOnHand - i.Quantity,
            ws.LastStockUpdate = GETDATE()
        FROM WarehouseStock ws
        JOIN inserted i ON ws.ProductID = i.ProductID AND ws.WarehouseID = i.WarehouseID;
    END
END;
GO

CREATE TRIGGER trg_UpdateOrderTotalAmount
ON OrderDetails
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AffectedOrderIDs TABLE (OrderID INT PRIMARY KEY);

    INSERT INTO @AffectedOrderIDs (OrderID)
    SELECT DISTINCT OrderID FROM inserted
    UNION
    SELECT DISTINCT OrderID FROM deleted;

    DECLARE @CurrentOrderID INT;
    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT OrderID FROM @AffectedOrderIDs;

    OPEN OrderCursor;
    FETCH NEXT FROM OrderCursor INTO @CurrentOrderID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        UPDATE Orders
        SET TotalAmount = dbo.fn_CalculateOrderTotalAmount(@CurrentOrderID)
        WHERE OrderID = @CurrentOrderID;

        FETCH NEXT FROM OrderCursor INTO @CurrentOrderID;
    END

    CLOSE OrderCursor;
    DEALLOCATE OrderCursor;
END;
GO

CREATE TRIGGER trg_PreventProductDeletionIfInStockOrOrders
ON Products
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductID INT;
    DECLARE @ErrorMsg NVARCHAR(500);
    DECLARE @CanDelete BIT = 1; -- Флаг возможности удаления

    -- Проверяем каждый товар из таблицы deleted (на случай массового удаления)
    DECLARE ProductCursor CURSOR LOCAL FAST_FORWARD FOR SELECT ProductID FROM deleted;
    OPEN ProductCursor;
    FETCH NEXT FROM ProductCursor INTO @ProductID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @CanDelete = 1; -- Сбрасываем флаг для каждого товара

        IF EXISTS (SELECT 1 FROM WarehouseStock WHERE ProductID = @ProductID AND QuantityOnHand > 0)
        BEGIN
            SET @ErrorMsg = FORMATMESSAGE('Нельзя удалить товар (ID: %d), так как он есть на складе.', @ProductID);
            RAISERROR(@ErrorMsg, 16, 1);
            SET @CanDelete = 0; -- Запрещаем удаление
        END

        IF @CanDelete = 1 AND EXISTS (SELECT 1 FROM OrderDetails od JOIN Orders o ON od.OrderID = o.OrderID
                   WHERE od.ProductID = @ProductID AND o.OrderStatus NOT IN ('Delivered', 'Cancelled'))
        BEGIN
            SET @ErrorMsg = FORMATMESSAGE('Нельзя удалить товар (ID: %d), так как он присутствует в активных заказах.', @ProductID);
            RAISERROR(@ErrorMsg, 16, 1);
            SET @CanDelete = 0;
        END

        IF @CanDelete = 1 AND EXISTS (SELECT 1 FROM OrderDetails WHERE ProductID = @ProductID) -- Проверка на наличие в любых заказах (исторических)
        BEGIN
            SET @ErrorMsg = FORMATMESSAGE('Нельзя удалить товар (ID: %d), так как он присутствует в истории заказов. Рекомендуется пометить как неактивный.', @ProductID);
            RAISERROR(@ErrorMsg, 16, 1);
            SET @CanDelete = 0;
        END

        IF @CanDelete = 1
        BEGIN
            -- Если все проверки пройдены, выполняем фактическое удаление
            DELETE FROM Products WHERE ProductID = @ProductID;
            PRINT FORMATMESSAGE('Товар (ID: %d) успешно удален.', @ProductID);
        END

        FETCH NEXT FROM ProductCursor INTO @ProductID;
    END

    CLOSE ProductCursor;
    DEALLOCATE ProductCursor;
END;
GO


CREATE TRIGGER trg_LogEmployeeChanges
ON Employees
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ChangedBy NVARCHAR(128) = SUSER_SNAME();

    -- Используем CTE для сравнения старых и новых значений по всем строкам
    WITH Changes AS (
        SELECT i.EmployeeID,
               d.PositionID AS OldPositionID, i.PositionID AS NewPositionID,
               d.IsActive AS OldIsActive, i.IsActive AS NewIsActive,
               d.Email AS OldEmail, i.Email AS NewEmail
        FROM inserted i
        JOIN deleted d ON i.EmployeeID = d.EmployeeID
    )
    INSERT INTO EmployeeAuditLog (EmployeeID, ChangedColumn, OldValue, NewValue, ChangedBy)
    SELECT
        EmployeeID, 'PositionID', CAST(OldPositionID AS NVARCHAR(MAX)), CAST(NewPositionID AS NVARCHAR(MAX)), @ChangedBy
    FROM Changes
    WHERE OldPositionID <> NewPositionID OR (OldPositionID IS NULL AND NewPositionID IS NOT NULL) OR (OldPositionID IS NOT NULL AND NewPositionID IS NULL)
    UNION ALL
    SELECT
        EmployeeID, 'IsActive', CAST(OldIsActive AS NVARCHAR(MAX)), CAST(NewIsActive AS NVARCHAR(MAX)), @ChangedBy
    FROM Changes
    WHERE OldIsActive <> NewIsActive
    UNION ALL
    SELECT
        EmployeeID, 'Email', OldEmail, NewEmail, @ChangedBy
    FROM Changes
    WHERE ISNULL(OldEmail, '') <> ISNULL(NewEmail, '');

END;
GO

PRINT 'База данных WholesaleDB и все объекты успешно созданы и заполнены начальными данными.';
GO
