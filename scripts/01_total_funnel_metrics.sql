WITH
  raw_data AS (
    -- Крок 1: Дедублікація — беремо тільки останній snapshot за кожен день для кожного ad_id
    SELECT *
    FROM `marketing_ads_raw`
    QUALIFY
      ROW_NUMBER() OVER (PARTITION BY ad_id, date ORDER BY timestamp DESC) = 1
  ),
  daily_metrics AS (
    -- Крок 2: Денні метрики — агрегація по (source, date)
    SELECT
      source,
      date,
      spend - LAG(spend, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_spend,
      impressions - LAG(impressions, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_impressions,
      clicks - LAG(clicks, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_clicks,
      installs - LAG(installs, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_installs,
      registrations - LAG(registrations, 1, 0)
        OVER (PARTITION BY ad_id ORDER BY date) AS daily_registrations
    FROM raw_data
  ),
  metrics_by_source AS (
    -- Крок 3: Метрики по каналу за весь період — агрегація поверх Кроку 2
    SELECT
      source,
      SUM(daily_spend) AS total_spend,
      SUM(daily_impressions) AS total_impressions,
      SUM(daily_clicks) AS total_clicks,
      SUM(daily_installs) AS total_installs,
      SUM(daily_registrations) AS total_registrations
    FROM daily_metrics
    GROUP BY source
  )

-- Фінальний SELECT: розрахунок усіх метрик воронки + LTV/CAC
SELECT
  source,
  ROUND(total_spend, 2) AS total_spend,
  ROUND((total_spend / NULLIF(total_impressions, 0)) * 1000, 2) AS cpm,
  ROUND((total_clicks / NULLIF(total_impressions, 0)) * 100, 2) AS ctr_pct,
  ROUND((total_installs / NULLIF(total_clicks, 0)) * 100, 2)
    AS cr_click_install_pct,
  ROUND((total_registrations / NULLIF(total_installs, 0)) * 100, 2)
    AS cr_install_reg_pct,
  ROUND(total_spend / NULLIF(total_registrations, 0), 2) AS cac,
  CASE
    WHEN source = 'tiktok' THEN 8.50
    WHEN source = 'meta' THEN 6.20
    WHEN source = 'google' THEN 12.40
    END AS ltv,
  ROUND(
    CASE
      WHEN source = 'tiktok' THEN 8.50
      WHEN source = 'meta' THEN 6.20
      WHEN source = 'google' THEN 12.40
      END / NULLIF(total_spend / NULLIF(total_registrations, 0), 0),
    2) AS ltv_cac
FROM metrics_by_source
ORDER BY ltv_cac DESC;
