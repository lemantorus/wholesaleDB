// script.js
const API_BASE_URL = 'http://localhost:3000/api';

// --- Элементы DOM для запросов данных ---
const viewSelect = document.getElementById('select-view');
const tableSelect = document.getElementById('select-table');
const btnFetchView = document.getElementById('btn-fetch-view');
const btnFetchTable = document.getElementById('btn-fetch-table');
const customerIdHistoryInput = document.getElementById('customer-id-history');
const btnFetchCustomerHistory = document.getElementById('btn-fetch-customer-history');
const lowStockWarehouseIdInput = document.getElementById('low-stock-warehouse-id');
const lowStockThresholdInput = document.getElementById('low-stock-threshold');
const btnFetchLowStock = document.getElementById('btn-fetch-low-stock');

// --- Элементы DOM для управления заказами ---
const newOrderCustomerIdInput = document.getElementById('new-order-customer-id');
const newOrderEmployeeIdInput = document.getElementById('new-order-employee-id');
const newOrderDeliveryDateInput = document.getElementById('new-order-delivery-date');
const newOrderShippingAddressInput = document.getElementById('new-order-shipping-address');
const btnCreateOrder = document.getElementById('btn-create-order');
const createOrderMessageArea = document.getElementById('create-order-message');
const currentOrderIdDisplay = document.getElementById('current-order-id-display');

const addItemOrderIdInput = document.getElementById('add-item-order-id');
const addItemProductIdInput = document.getElementById('add-item-product-id');
const addItemWarehouseIdInput = document.getElementById('add-item-warehouse-id');
const addItemQuantityInput = document.getElementById('add-item-quantity');
const btnAddItemToOrder = document.getElementById('btn-add-item-to-order');
const addItemMessageArea = document.getElementById('add-item-message');

// --- Элементы DOM для отображения результатов ---
const resultsTable = document.getElementById('results-table');
const tableHead = resultsTable.querySelector('thead');
const tableBody = resultsTable.querySelector('tbody');
const mainMessageArea = document.getElementById('message-area');


// --- Вспомогательные функции API ---
async function fetchData(endpoint, targetMessageArea = mainMessageArea) {
    targetMessageArea.textContent = 'Загрузка...';
    targetMessageArea.className = 'message-area'; // Сброс классов
    try {
        const response = await fetch(`${API_BASE_URL}/${endpoint}`);
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ message: response.statusText }));
            throw new Error(errorData.message || `HTTP ошибка: ${response.status}`);
        }
        targetMessageArea.textContent = ''; // Очистить сообщение при успехе
        return await response.json();
    } catch (error) {
        console.error('Fetch error:', error);
        targetMessageArea.textContent = `Ошибка: ${error.message}`;
        targetMessageArea.classList.add('error-message');
        return null;
    }
}

async function postData(endpoint, data, targetMessageArea) {
    targetMessageArea.textContent = 'Отправка данных...';
    targetMessageArea.className = 'message-area'; // Сброс классов
    try {
        const response = await fetch(`${API_BASE_URL}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        const responseData = await response.json();
        if (!response.ok) {
            const error = new Error(responseData.message || `HTTP ошибка: ${response.status}`);
            error.details = responseData.errorDetail;
            error.isApiError = true;
            throw error;
        }
        targetMessageArea.textContent = responseData.message || 'Операция успешна!';
        targetMessageArea.classList.add('success-message');
        return responseData;
    } catch (error) {
        console.error('POST error:', error);
        if (error.isApiError) {
            targetMessageArea.textContent = `Ошибка API: ${error.message}`;
            if (error.details) targetMessageArea.textContent += ` Детали: ${error.details}`;
        } else {
            targetMessageArea.textContent = `Сетевая ошибка или ошибка JS: ${error.message}`;
        }
        targetMessageArea.classList.add('error-message');
        throw error; // Перебрасываем для дополнительной обработки, если нужно
    }
}

// --- Отображение данных в таблице ---
function displayDataInTable(data) {
    tableHead.innerHTML = '';
    tableBody.innerHTML = '';
    mainMessageArea.textContent = '';
    mainMessageArea.className = 'message-area';


    if (!data || data.length === 0) {
        mainMessageArea.textContent = 'Нет данных для отображения.';
        return;
    }

    const headers = Object.keys(data[0]);
    const headerRow = document.createElement('tr');
    headers.forEach(headerText => {
        const th = document.createElement('th');
        th.textContent = headerText;
        headerRow.appendChild(th);
    });
    tableHead.appendChild(headerRow);

    data.forEach(rowData => {
        const row = document.createElement('tr');
        headers.forEach(header => {
            const td = document.createElement('td');
            let value = rowData[header];
            if (typeof value === 'string' && value.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)) {
                try {
                    value = new Date(value).toLocaleString('ru-RU', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
                } catch (e) { /* 그대로 둠 */ }
            }
            td.textContent = (value === null || value === undefined) ? '' : value;
            row.appendChild(td);
        });
        tableBody.appendChild(row);
    });
}

// --- Заполнение выпадающих списков ---
async function populateSelectWithOptions(selectElement, endpoint, placeholder) {
    while (selectElement.options.length > 1) selectElement.remove(1);
    selectElement.options[0].textContent = `${placeholder} (загрузка...)`;
    const items = await fetchData(endpoint, mainMessageArea); // Используем mainMessageArea для ошибок загрузки списков
    if (items) {
        items.forEach(item => {
            const option = new Option(item, item);
            selectElement.add(option);
        });
        selectElement.options[0].textContent = placeholder;
    } else {
        selectElement.options[0].textContent = `${placeholder} (ошибка загрузки)`;
    }
}

// --- Обработчики событий ---
document.addEventListener('DOMContentLoaded', () => {
    populateSelectWithOptions(viewSelect, 'views', '-- Представления --');
    populateSelectWithOptions(tableSelect, 'tables', '-- Таблицы --');

    btnFetchView.addEventListener('click', async () => {
        if (viewSelect.value) displayDataInTable(await fetchData(`data/${viewSelect.value}`));
        else mainMessageArea.textContent = 'Выберите представление.';
    });

    btnFetchTable.addEventListener('click', async () => {
        if (tableSelect.value) displayDataInTable(await fetchData(`data/${tableSelect.value}`));
        else mainMessageArea.textContent = 'Выберите таблицу.';
    });

    btnFetchCustomerHistory.addEventListener('click', async () => {
        if (customerIdHistoryInput.value) displayDataInTable(await fetchData(`customer/${customerIdHistoryInput.value}/orders`));
        else mainMessageArea.textContent = 'Введите ID клиента.';
    });

    btnFetchLowStock.addEventListener('click', async () => {
        let queryParams = [];
        if (lowStockWarehouseIdInput.value) queryParams.push(`warehouseId=${encodeURIComponent(lowStockWarehouseIdInput.value)}`);
        if (lowStockThresholdInput.value) queryParams.push(`threshold=${encodeURIComponent(lowStockThresholdInput.value)}`);
        const queryString = queryParams.length > 0 ? `?${queryParams.join('&')}` : '';
        displayDataInTable(await fetchData(`products/lowstock${queryString}`));
    });

    // Создание заказа
    btnCreateOrder.addEventListener('click', async () => {
        const customerId = parseInt(newOrderCustomerIdInput.value);
        const employeeId = parseInt(newOrderEmployeeIdInput.value);

        if (isNaN(customerId) || isNaN(employeeId)) {
            createOrderMessageArea.textContent = 'ID клиента и ID сотрудника обязательны и должны быть числами.';
            createOrderMessageArea.className = 'message-area error-message';
            return;
        }

        const orderData = {
            customerId,
            employeeId,
            requiredDeliveryDate: newOrderDeliveryDateInput.value || null,
            shippingAddress: newOrderShippingAddressInput.value.trim() || null,
        };

        try {
            const result = await postData('orders', orderData, createOrderMessageArea);
            if (result && result.orderId) {
                currentOrderIdDisplay.textContent = result.orderId;
                addItemOrderIdInput.value = result.orderId; // Авто-заполнение ID заказа для добавления товаров
                // Очистка формы создания
                newOrderCustomerIdInput.value = '';
                newOrderEmployeeIdInput.value = '';
                newOrderDeliveryDateInput.value = '';
                newOrderShippingAddressInput.value = '';
            }
        } catch (error) {
            console.error("Ошибка при создании заказа (слушатель):", error);
            currentOrderIdDisplay.textContent = 'ошибка';
        }
    });

    // Добавление товара в заказ
    btnAddItemToOrder.addEventListener('click', async () => {
        const orderId = parseInt(addItemOrderIdInput.value);
        const productId = parseInt(addItemProductIdInput.value);
        const warehouseId = parseInt(addItemWarehouseIdInput.value);
        const quantity = parseInt(addItemQuantityInput.value);

        if (isNaN(orderId) || isNaN(productId) || isNaN(warehouseId) || isNaN(quantity)) {
            addItemMessageArea.textContent = 'Все поля (ID заказа, ID товара, ID склада, Количество) обязательны и должны быть числами.';
            addItemMessageArea.className = 'message-area error-message';
            return;
        }
        if (quantity <= 0) {
            addItemMessageArea.textContent = 'Количество должно быть больше нуля.';
            addItemMessageArea.className = 'message-area error-message';
            return;
        }

        const itemData = { productId, warehouseId, quantity };

        try {
            // `postData` сама обновит `addItemMessageArea`
            await postData(`orders/${orderId}/items`, itemData, addItemMessageArea);
            // Очистка полей товара после успешного добавления
            addItemProductIdInput.value = '';
            addItemWarehouseIdInput.value = '';
            addItemQuantityInput.value = '1';
        } catch (error) {
            console.error("Ошибка при добавлении товара в заказ (слушатель):", error);
        }
    });
});