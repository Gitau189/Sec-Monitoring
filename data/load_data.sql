-- Load the generated CSVs into the company schema.
-- Run AFTER the stack is up and data has been generated:  make load
-- The /data path is the data/generated folder mounted into the postgres container.

SET search_path TO company, public;

\echo Loading customers...
COPY company.customers(customer_id, full_name, email, phone, country, ssn, credit_score, created_at)
    FROM '/data/customers.csv' WITH (FORMAT csv);

\echo Loading transactions...
COPY company.transactions(txn_id, customer_id, amount, currency, txn_type, status, txn_time)
    FROM '/data/transactions.csv' WITH (FORMAT csv);

\echo Loading employees...
COPY company.employees(employee_id, full_name, department, role_title, salary, hired_at)
    FROM '/data/employees.csv' WITH (FORMAT csv);

ANALYZE company.customers;
ANALYZE company.transactions;
ANALYZE company.employees;

\echo Row counts:
SELECT 'customers'    AS table, count(*) FROM company.customers
UNION ALL
SELECT 'transactions', count(*) FROM company.transactions
UNION ALL
SELECT 'employees',    count(*) FROM company.employees;
