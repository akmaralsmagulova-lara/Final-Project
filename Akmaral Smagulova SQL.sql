select * from customers;
select * from transactions;

#1. Клиенты с непрерывной историей (12 месяцев)
WITH monthly_activity AS (
    SELECT 
        id_client,
        DATE_FORMAT(date_new, '%Y-%m') AS ym
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY id_client, ym
),

clients_12m AS (
    SELECT id_client
    FROM monthly_activity
    GROUP BY id_client
    HAVING COUNT(*) = 12
)

SELECT 
    t.id_client,
    AVG(t.sum_payment) AS avg_check,
    SUM(t.sum_payment)/12 AS avg_monthly_spend,
    COUNT(t.id_check) AS total_operations
FROM transactions t
JOIN clients_12m c USING(id_client)
WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'
GROUP BY t.id_client;

#Разрез по месяцам
SELECT 
    id_client,
    DATE_FORMAT(date_new, '%Y-%m') AS ym,
    COUNT(id_check) AS operations,
    SUM(sum_payment) AS revenue,
    AVG(sum_payment) AS avg_check
FROM transactions
WHERE date_new >= '2015-06-01'
  AND date_new < '2016-06-01'
GROUP BY id_client, ym;

#2. Метрики по месяцам

#a) Средний чек в месяц
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS ym,
    AVG(sum_payment) AS avg_check
FROM transactions
GROUP BY ym;

#b) Среднее количество операций в месяц
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS ym,
    COUNT(id_check) AS operations
FROM transactions
GROUP BY ym;

#c) Среднее количество клиентов
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS ym,
    COUNT(DISTINCT id_client) AS unique_clients
FROM transactions
GROUP BY ym;


#d) Доли
WITH monthly AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m') AS ym,
        COUNT(*) AS ops,
        SUM(sum_payment) AS revenue
    FROM transactions
    GROUP BY ym
),
total AS (
    SELECT 
        COUNT(*) AS total_ops,
        SUM(sum_payment) AS total_revenue
    FROM transactions
)

SELECT 
    m.ym,
    m.ops / t.total_ops AS share_ops,
    m.revenue / t.total_revenue AS share_revenue
FROM monthly m, total t;

#e) % M / F / NA + доля затрат
SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
    c.gender,
    COUNT(DISTINCT t.id_client) * 1.0 /
        SUM(COUNT(DISTINCT t.id_client)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) 
        AS gender_share,
    SUM(t.sum_payment) /
        SUM(SUM(t.sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) 
        AS spend_share
FROM transactions t
LEFT JOIN customers c USING(id_client)
GROUP BY ym, c.gender;


#3. Возрастные группы
WITH age_calc AS (
    SELECT 
        id_client,
        CASE 
            WHEN age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(age/10)*10, '-', FLOOR(age/10)*10 + 10)
        END AS age_group
    FROM customers
)

SELECT 
    a.age_group,
    COUNT(t.id_check) AS operations,
    SUM(t.sum_payment) AS revenue
FROM transactions t
JOIN age_calc a USING(id_client)
GROUP BY a.age_group;

#Поквартально (средние + сумма + операции)
WITH age_calc AS (
    SELECT 
        id_client,
        CASE 
            WHEN age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(age/10)*10, '-', FLOOR(age/10)*10 + 10)
        END AS age_group
    FROM customers
)

SELECT 
    a.age_group,
    CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,
    COUNT(t.id_check) AS operations,
    SUM(t.sum_payment) AS revenue,
    AVG(t.sum_payment) AS avg_check
FROM transactions t
JOIN age_calc a USING(id_client)
WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'
GROUP BY a.age_group, quarter
ORDER BY quarter, a.age_group;

# Финальный запрос с процентами:
WITH age_calc AS (
    SELECT 
        id_client,
        CASE 
            WHEN age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(age/10)*10, '-', FLOOR(age/10)*10 + 10)
        END AS age_group
    FROM customers
),

base AS (
    SELECT 
        a.age_group,
        CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,
        t.id_check,
        t.sum_payment
    FROM transactions t
    JOIN age_calc a USING(id_client)
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
)

SELECT 
    age_group,
    quarter,
    
    COUNT(id_check) AS operations,
    SUM(sum_payment) AS revenue,
    AVG(sum_payment) AS avg_check,

    -- % операций внутри квартала
    COUNT(id_check) * 1.0 /
        SUM(COUNT(id_check)) OVER (PARTITION BY quarter) 
        AS operations_share,

    -- % выручки внутри квартала
    SUM(sum_payment) * 1.0 /
        SUM(SUM(sum_payment)) OVER (PARTITION BY quarter) 
        AS revenue_share

FROM base
GROUP BY age_group, quarter
ORDER BY quarter, age_group;

