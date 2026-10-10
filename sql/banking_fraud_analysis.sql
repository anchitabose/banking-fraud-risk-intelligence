CREATE TABLE transactions (
    transaction_id         VARCHAR(20),
    customer_id            VARCHAR(20),
    transaction_date       DATE,
    transaction_time       TIME,
    account_type           VARCHAR(20),
    transaction_type       VARCHAR(20),
    transaction_amount     DECIMAL(12,2),
    transaction_direction  VARCHAR(10),
    account_balance        DECIMAL(12,2),
    merchant_category      VARCHAR(30),
    state                  VARCHAR(30),
    credit_score           INT,
    has_loan               TINYINT,
    loan_type              VARCHAR(20),
    emi_amount             DECIMAL(10,2),
    transaction_status     VARCHAR(20),
    channel                VARCHAR(20),
    kyc_status             VARCHAR(20),
    is_fraud               TINYINT,
    transaction_hour       INT
);

SHOW VARIABLES LIKE 'secure_file_priv';

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/cleaned_transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 1. Row count check — should be exactly 550,000
SELECT COUNT(*) FROM transactions;

-- 2. Spot-check the first few rows look right, no columns shifted/misaligned
SELECT * FROM transactions LIMIT 5;

-- 3. Confirm is_fraud only contains 0 and 1, and check total fraud count matches your Python finding (4,873)
SELECT is_fraud, COUNT(*) FROM transactions GROUP BY is_fraud;

-- Q1: Overall summary — total transactions, total value, fraud count, fraud rate
SELECT 
    COUNT(*) AS total_transactions,
    SUM(transaction_amount) AS total_value,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3) AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN transaction_amount ELSE 0 END), 2) AS fraud_value_exposed
FROM transactions;

-- 4. Confirm dates loaded as real dates, not text — this should return a sensible min/max, not an error
SELECT MIN(transaction_date), MAX(transaction_date) FROM transactions;

SELECT 
    transaction_type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions 
GROUP BY transaction_type 
ORDER BY fraud_rate_pct DESC;

SELECT
	merchant_category,
	COUNT(*) AS total_transactions,
	ROUND(SUM(is_fraud)*100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY merchant_category
ORDER BY fraud_rate_pct DESC;

SELECT
	state,
	COUNT(*) AS total_transactions,
	ROUND(SUM(is_fraud)*100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY state
ORDER BY fraud_rate_pct DESC;

SELECT
	transaction_hour,
	COUNT(*) AS total_transactions,
	ROUND(SUM(is_fraud)*100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY transaction_hour
ORDER BY transaction_hour;

SELECT 
	customer_id,
    COUNT(*) AS total_frauds
FROM transactions
WHERE is_fraud = 1
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY total_frauds DESC;

SELECT
	customer_id, 
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY customer_id
HAVING COUNT(is_fraud) > 2
ORDER BY fraud_rate_pct DESC;

SELECT
    kyc_status,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY kyc_status
ORDER BY fraud_rate_pct DESC;

SELECT
    CASE
        WHEN credit_score < 600 THEN 'Poor (<600)'
        WHEN credit_score BETWEEN 600 AND 749 THEN 'Fair (600-749)'
        WHEN credit_score BETWEEN 750 AND 849 THEN 'Good (750-849)'
        ELSE 'Excellent (850+)'
    END AS credit_score_band,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY credit_score_band
ORDER BY fraud_rate_pct DESC;

SELECT
    YEAR(transaction_date) AS txn_year,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3) AS fraud_rate_pct
FROM transactions
GROUP BY txn_year
ORDER BY txn_year;