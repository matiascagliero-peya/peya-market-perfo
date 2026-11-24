DECLARE query_name STRING DEFAULT 'carrefour_express_detail';

SELECT
  o.order_code,
  o.rider.order_id,
  o.rider.vendor.name AS vendor_name,
  d.rider_id,
  d.rider_picked_up_at,
  TIME(d.rider_picked_up_at, 'America/Argentina/Buenos_Aires') AS pickup_local_time,
  o.rider.total_weight,
  o.rider.total_volume,
  d.delivery_status
FROM `peya-data-origins-pro.cl_hurrier.orders_v2` o
LEFT JOIN UNNEST(o.rider.deliveries) d
WHERE o.created_date = '2026-11-19'
  AND LOWER(o.rider.vendor.name) LIKE '%carrefour%'
  AND LOWER(o.rider.vendor.name) LIKE '%express%'
  AND TIME(d.rider_picked_up_at, 'America/Argentina/Buenos_Aires') BETWEEN TIME(11, 30, 0) AND TIME(12, 15, 0)
ORDER BY pickup_local_time ASC;
