DECLARE query_name STRING DEFAULT '3. Frank - User Type (Level 1 & 2 + Tenure)';

-- ==============================================================================
-- Frank - User Type (Modernizado: Nivel Mensual)
-- Granularidad: Mes (DATE_TRUNC primer día de mes), customer_id, country
--
-- Columnas Objetivo:
--   - Mes, customer_id, country
--
--   - PLATFORM:
--       Platform_adoption_date
--       Platform_user_adoption_tenure
--       Platform_previous_type
--       Platform_Actual_type_ternure
--       Platform_Actual_Type
--
--   - AAA:
--       AAA_adoption_date
--       AAA_user_adoption_tenure
--       AAA_previous_type
--       AAA_Actual_type_ternure
--       AAA_Actual_Type
--
--   - MARKET (Adopción General):
--       Market_adoption_date
--       Market_user_adoption_tenure
--
--   - MARKET L1:
--       Market_L1_previous_type_ternure
--       Market_L1_previous_type
--       Market_L1_type_ternure
--       Market_L1_Actual_Type
--
--   - MARKET L2:
--       Market_L2_previous_type_ternure
--       Market_L2_previous_type
--       Market_L2_type_ternure
--       Market_L2_Actual_Type
--
--   - FLAGS / ÓRDENES DEL MES:
--       DY_order
--       UF_order
-- ==============================================================================

CREATE OR REPLACE TABLE `peya-food-and-groceries.automated_tables_reports.frank_user_type` AS

-- [Estructura en desarrollo según especificaciones]
SELECT NULL;
