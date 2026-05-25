WITH
  deduped_data AS (
    SELECT *
    FROM `marketing_ads_raw`
    QUALIFY
      ROW_NUMBER() OVER (PARTITION BY ad_id, date ORDER BY timestamp DESC) = 1
  ),
  daily_deltas AS (
    SELECT
      source,
      date,
      spend - LAG(spend, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_spend,
      registrations - LAG(registrations, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_registrations
    FROM deduped_data
  ),
  monthly_metrics AS (
    SELECT
      source,
      DATE_TRUNC(date, MONTH) AS month_date,
      SUM(daily_spend) AS total_spend,
      SUM(daily_registrations) AS total_registrations
    FROM daily_deltas
    GROUP BY 1, 2
  )
SELECT
  source,
  FORMAT_DATE('%Y-%m', month_date) AS month,
  ROUND(total_spend, 2) AS spend,
  total_registrations AS regs,
  ROUND(total_spend / NULLIF(total_registrations, 0), 2) AS cac
FROM monthly_metrics
ORDER BY source, month;
