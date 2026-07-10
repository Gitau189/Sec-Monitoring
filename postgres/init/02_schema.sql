CREATE TABLE IF NOT EXISTS customers (
    customer_id     SERIAL PRIMARY KEY,
    full_name       TEXT NOT NULL,
    email           TEXT NOT NULL,
    phone           TEXT,
    national_id     TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id  SERIAL PRIMARY KEY,
    customer_id     INTEGER REFERENCES customers(customer_id),
    amount          NUMERIC(10,2) NOT NULL,
    merchant        TEXT NOT NULL,
    card_last4      CHAR(4) NOT NULL,
    transaction_date TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_customer ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);
