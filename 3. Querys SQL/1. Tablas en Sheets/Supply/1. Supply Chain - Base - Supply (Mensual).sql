DECLARE query_name STRING DEFAULT '1. Supply Chain - Base - Supply (Mensual)';

-- 1. Supply Chain - Base - Supply
SELECT
    DATE_TRUNC(a.fecha, MONTH) AS mes,
    a.country_code,
    c.country_name,

    -- ===== WIS total =====
    SUM(a.wis_numerador)                                              AS wis_numerador,
    SUM(a.wis_denominador)                                            AS wis_denominador,
    SAFE_DIVIDE(SUM(a.wis_numerador), SUM(a.wis_denominador))         AS wis,

    -- ===== WIS Ultra Fresh =====
    SUM(a.wis_uf_numerador)                                           AS wis_uf_numerador,
    SUM(a.wis_uf_denominador)                                         AS wis_uf_denominador,
    SAFE_DIVIDE(SUM(a.wis_uf_numerador), SUM(a.wis_uf_denominador))   AS wis_ultra_fresh,

    -- ===== Peya Issues (total) =====
    SUM(a.peya_issues_numerador)                                      AS peya_issues_numerador,
    SUM(a.peya_issues_denominador)                                    AS peya_issues_denominador,
    SAFE_DIVIDE(SUM(a.peya_issues_numerador), SUM(a.peya_issues_denominador)) AS peya_issues,

    -- ===== Peya Issues (Ultra Fresh) =====
    SUM(a.peya_issues_uf_numerador)                                   AS peya_issues_uf_numerador,
    SUM(a.peya_issues_uf_denominador)                                 AS peya_issues_uf_denominador,
    SAFE_DIVIDE(SUM(a.peya_issues_uf_numerador), SUM(a.peya_issues_uf_denominador)) AS peya_issues_uf,

    -- ===== Supplier + P&N Issues (total) =====
    SUM(a.supplier_issues_numerador)                                 AS supplier_issues_numerador,
    SUM(a.supplier_issues_denominador)                               AS supplier_issues_denominador,
    SAFE_DIVIDE(SUM(a.supplier_issues_numerador), SUM(a.supplier_issues_denominador)) AS supplier_issues,

    -- ===== Supplier + P&N Issues (Ultra Fresh) =====
    SUM(a.supplier_issues_uf_numerador)                              AS supplier_issues_uf_numerador,
    SUM(a.supplier_issues_uf_denominador)                            AS supplier_issues_uf_denominador,
    SAFE_DIVIDE(SUM(a.supplier_issues_uf_numerador), SUM(a.supplier_issues_uf_denominador)) AS supplier_issues_uf

FROM `peya-food-and-groceries.automated_tables_reports.absolute_okrs_supply` a
LEFT JOIN (
    SELECT LOWER(country_code) AS cc, ANY_VALUE(country_name_en) AS country_name
    FROM `peya-bi-tools-pro.il_core.dim_country`
    GROUP BY 1
) c ON a.country_code = c.cc
GROUP BY 1, 2, 3
ORDER BY country_name, mes;