-- CloudOps Finance — Database initialization
-- Run once after the RDS instance is reachable.
-- 
-- Connect with: psql -h <RDS_ENDPOINT> -U cloudopsadmin -d cloudops

CREATE TABLE IF NOT EXISTS entries (
    id          SERIAL PRIMARY KEY,
    description VARCHAR(100) NOT NULL,
    amount      NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    entry_type  VARCHAR(10) NOT NULL CHECK (entry_type IN ('income', 'expense')),
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_entries_created_at ON entries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_entries_type ON entries (entry_type);

-- Sample data for demo purposes
INSERT INTO entries (description, amount, entry_type) VALUES
    ('Salary',          5000.00, 'income'),
    ('Rent',            1200.00, 'expense'),
    ('Groceries',        350.00, 'expense'),
    ('Freelance project', 800.00, 'income'),
    ('Internet bill',     60.00, 'expense');
