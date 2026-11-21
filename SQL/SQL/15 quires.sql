USE logistics;

SELECT
    s.shipment_id,
    o.order_id,
    c.customer_name,
    c.city AS customer_city,
    ca.carrier_name,
    s.shipment_type,
    s.current_status,

    r.route_id,
    oh.hub_name AS origin_hub,
    dh.hub_name AS destination_hub,

    se.event_type,
    se.event_timestamp,
    eh.hub_name AS event_hub

FROM shipments s

JOIN customer_orders o
    ON s.order_id = o.order_id

JOIN customers c
    ON o.customer_id = c.customer_id

JOIN carriers ca
    ON s.carrier_id = ca.carrier_id

JOIN routes r
    ON s.route_id = r.route_id

JOIN hubs oh
    ON r.origin_hub_id = oh.hub_id

JOIN hubs dh
    ON r.destination_hub_id = dh.hub_id

LEFT JOIN shipment_events se
    ON s.shipment_id = se.shipment_id

LEFT JOIN hubs eh
    ON se.hub_id = eh.hub_id

ORDER BY s.shipment_id, se.event_timestamp;


USE logistics;

SELECT
    c.carrier_name,
    COUNT(s.shipment_id) AS total_shipments
FROM carriers c
LEFT JOIN shipments s
    ON c.carrier_id = s.carrier_id
GROUP BY
    c.carrier_id,
    c.carrier_name
ORDER BY total_shipments DESC;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
)

SELECT
    shipment_id,
    dispatch_time,
    delivery_time,

    ROUND(
        TIMESTAMPDIFF(
            MINUTE,
            dispatch_time,
            delivery_time
        ) / 60,
        2
    ) AS delivery_duration_hours

FROM shipment_times

WHERE dispatch_time IS NOT NULL
AND delivery_time IS NOT NULL
AND delivery_time >= dispatch_time

ORDER BY shipment_id;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
),

valid_deliveries AS (
    SELECT
        s.shipment_id,
        s.promised_delivery_at,
        st.dispatch_time,
        st.delivery_time

    FROM shipments s

    JOIN shipment_times st
        ON s.shipment_id = st.shipment_id

    WHERE s.current_status = 'DELIVERED'
      AND st.dispatch_time IS NOT NULL
      AND st.delivery_time IS NOT NULL
      AND st.delivery_time >= st.dispatch_time
)

SELECT
    COUNT(*) AS total_valid_deliveries,

    SUM(CASE
        WHEN delivery_time <= promised_delivery_at
        THEN 1 ELSE 0
    END) AS on_time_shipments,

    SUM(CASE
        WHEN delivery_time > promised_delivery_at
        THEN 1 ELSE 0
    END) AS late_shipments,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN delivery_time <= promised_delivery_at
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_percentage

FROM valid_deliveries;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
)

SELECT
    s.shipment_id,
    ca.carrier_name,
    s.promised_delivery_at,
    st.delivery_time,

    ROUND(
        TIMESTAMPDIFF(
            MINUTE,
            s.promised_delivery_at,
            st.delivery_time
        ) / 60,
        2
    ) AS delay_hours

FROM shipments s

JOIN shipment_times st
    ON s.shipment_id = st.shipment_id

JOIN carriers ca
    ON s.carrier_id = ca.carrier_id

WHERE s.current_status = 'DELIVERED'
  AND st.dispatch_time IS NOT NULL
  AND st.delivery_time IS NOT NULL
  AND st.delivery_time >= st.dispatch_time
  AND st.delivery_time > s.promised_delivery_at

ORDER BY delay_hours DESC;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
),

shipment_metrics AS (
    SELECT
        s.shipment_id,
        ca.carrier_name,
        rg.region_name,
        s.current_status,
        s.promised_delivery_at,
        st.dispatch_time,
        st.delivery_time,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
            THEN 1
            ELSE 0
        END AS valid_delivery_flag,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
             AND st.delivery_time <= s.promised_delivery_at
            THEN 1
            ELSE 0
        END AS on_time_flag,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
             AND st.delivery_time > s.promised_delivery_at
            THEN 1
            ELSE 0
        END AS late_flag,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
            THEN TIMESTAMPDIFF(
                MINUTE,
                st.dispatch_time,
                st.delivery_time
            ) / 60.0
        END AS delivery_duration_hours

    FROM shipments s

    JOIN carriers ca
        ON s.carrier_id = ca.carrier_id

    JOIN routes r
        ON s.route_id = r.route_id

    JOIN hubs h
        ON r.destination_hub_id = h.hub_id

    JOIN regions rg
        ON h.region_id = rg.region_id

    LEFT JOIN shipment_times st
        ON s.shipment_id = st.shipment_id
)

SELECT
    carrier_name,
    region_name,

    COUNT(shipment_id) AS total_shipments,

    SUM(valid_delivery_flag) AS valid_completed_deliveries,

    SUM(on_time_flag) AS on_time_shipments,

    SUM(late_flag) AS late_shipments,

    ROUND(
        100.0 * SUM(on_time_flag) /
        NULLIF(SUM(valid_delivery_flag), 0),
        2
    ) AS on_time_percentage,

    ROUND(
        AVG(delivery_duration_hours),
        2
    ) AS avg_delivery_hours

FROM shipment_metrics

GROUP BY carrier_name, region_name

ORDER BY carrier_name, region_name;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
)

SELECT
    DAYNAME(st.dispatch_time) AS dispatch_weekday,

    s.shipment_type,

    COUNT(*) AS completed_shipments,

    ROUND(
        AVG(
            TIMESTAMPDIFF(
                MINUTE,
                st.dispatch_time,
                st.delivery_time
            ) / 60.0
        ),
        2
    ) AS avg_delivery_hours

FROM shipments s

JOIN shipment_times st
    ON s.shipment_id = st.shipment_id

WHERE s.current_status = 'DELIVERED'
  AND st.dispatch_time IS NOT NULL
  AND st.delivery_time IS NOT NULL
  AND st.delivery_time >= st.dispatch_time

GROUP BY
    DAYOFWEEK(st.dispatch_time),
    DAYNAME(st.dispatch_time),
    s.shipment_type

ORDER BY
    DAYOFWEEK(st.dispatch_time),
    s.shipment_type;
    
    
    USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
)

SELECT
    s.shipment_id,
    s.current_status,
    st.dispatch_time,
    st.delivery_time,

    CASE
        WHEN st.dispatch_time IS NULL
         AND st.delivery_time IS NULL
            THEN 'Both timestamps missing'

        WHEN st.dispatch_time IS NULL
            THEN 'Dispatch timestamp missing'

        WHEN st.delivery_time IS NULL
            THEN 'Delivery timestamp missing'
    END AS missing_timestamp_issue

FROM shipments s

LEFT JOIN shipment_times st
    ON s.shipment_id = st.shipment_id

WHERE st.dispatch_time IS NULL
   OR st.delivery_time IS NULL

ORDER BY s.shipment_id;


USE logistics;

SELECT
    shipment_id,
    event_type,
    event_timestamp,
    hub_id,

    COUNT(*) AS duplicate_count

FROM shipment_events

GROUP BY
    shipment_id,
    event_type,
    event_timestamp,
    hub_id

HAVING COUNT(*) > 1

ORDER BY shipment_id;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
)

SELECT
    shipment_id,
    dispatch_time,
    delivery_time,

    TIMESTAMPDIFF(
        MINUTE,
        delivery_time,
        dispatch_time
    ) AS chronology_error_minutes

FROM shipment_times

WHERE dispatch_time IS NOT NULL
  AND delivery_time IS NOT NULL
  AND delivery_time < dispatch_time

ORDER BY shipment_id;


USE logistics;

SELECT
    s.shipment_id,
    c.carrier_name,
    s.current_status,

    COUNT(da.attempt_id) AS total_attempts,

    SUM(
        CASE
            WHEN da.attempt_result = 'FAILED'
            THEN 1
            ELSE 0
        END
    ) AS failed_attempts

FROM shipments s

JOIN delivery_attempts da
    ON s.shipment_id = da.shipment_id

JOIN carriers c
    ON s.carrier_id = c.carrier_id

GROUP BY
    s.shipment_id,
    c.carrier_name,
    s.current_status

HAVING SUM(
    CASE
        WHEN da.attempt_result = 'FAILED'
        THEN 1
        ELSE 0
    END
) > 1

ORDER BY failed_attempts DESC;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
)

SELECT
    s.shipment_id,
    ca.carrier_name,
    st.dispatch_time,
    s.estimated_delivery_at,
    st.delivery_time,

    ROUND(
        TIMESTAMPDIFF(
            MINUTE,
            st.dispatch_time,
            s.estimated_delivery_at
        ) / 60.0,
        2
    ) AS estimated_duration_hours,

    ROUND(
        TIMESTAMPDIFF(
            MINUTE,
            st.dispatch_time,
            st.delivery_time
        ) / 60.0,
        2
    ) AS actual_duration_hours,

    ROUND(
        TIMESTAMPDIFF(
            MINUTE,
            s.estimated_delivery_at,
            st.delivery_time
        ) / 60.0,
        2
    ) AS duration_difference_hours

FROM shipments s

JOIN shipment_times st
    ON s.shipment_id = st.shipment_id

JOIN carriers ca
    ON s.carrier_id = ca.carrier_id

WHERE s.current_status = 'DELIVERED'
  AND st.dispatch_time IS NOT NULL
  AND st.delivery_time IS NOT NULL
  AND s.estimated_delivery_at IS NOT NULL
  AND st.delivery_time >= st.dispatch_time
  AND s.estimated_delivery_at >= st.dispatch_time

ORDER BY s.shipment_id;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
),

valid_shipments AS (
    SELECT
        s.shipment_id,
        s.promised_delivery_at,
        st.delivery_time

    FROM shipments s

    JOIN shipment_times st
        ON s.shipment_id = st.shipment_id

    WHERE s.current_status = 'DELIVERED'
      AND st.dispatch_time IS NOT NULL
      AND st.delivery_time IS NOT NULL
      AND st.delivery_time >= st.dispatch_time
)

SELECT
    COUNT(*) AS total_valid_shipments,

    SUM(CASE
        WHEN delivery_time <= promised_delivery_at
        THEN 1 ELSE 0
    END) AS sla_met,

    SUM(CASE
        WHEN delivery_time > promised_delivery_at
        THEN 1 ELSE 0
    END) AS sla_breached,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN delivery_time <= promised_delivery_at
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS sla_compliance_percentage

FROM valid_shipments;


USE logistics;

WITH ranked_events AS (
    SELECT
        shipment_id,
        event_id,
        event_type,
        event_timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY shipment_id
            ORDER BY event_timestamp DESC, event_id DESC
        ) AS row_num

    FROM shipment_events
),

latest_events AS (
    SELECT
        shipment_id,
        event_type,
        event_timestamp

    FROM ranked_events
    WHERE row_num = 1
),

reconciliation AS (
    SELECT
        s.shipment_id,
        s.current_status,
        le.event_type AS latest_event_type,
        le.event_timestamp AS latest_event_timestamp,

        CASE
            WHEN le.event_type = 'CREATED'
                THEN 'CREATED'

            WHEN le.event_type IN (
                'DISPATCHED',
                'HUB_ARRIVAL',
                'HUB_DEPARTURE'
            )
                THEN 'IN_TRANSIT'

            WHEN le.event_type IN (
                'OUT_FOR_DELIVERY',
                'DELIVERY_ATTEMPT_FAILED'
            )
                THEN 'OUT_FOR_DELIVERY'

            WHEN le.event_type = 'DELIVERED'
                THEN 'DELIVERED'

            WHEN le.event_type = 'DELIVERY_FAILED'
                THEN 'FAILED'

            WHEN le.event_type = 'CANCELLED'
                THEN 'CANCELLED'

            WHEN le.event_type = 'RETURNED'
                THEN 'RETURNED'

            WHEN le.event_type = 'EXCEPTION'
                THEN 'EXCEPTION'

            ELSE 'UNKNOWN'
        END AS expected_status

    FROM shipments s

    LEFT JOIN latest_events le
        ON s.shipment_id = le.shipment_id
)

SELECT
    shipment_id,
    current_status,
    latest_event_type,
    latest_event_timestamp,
    expected_status,

    CASE
        WHEN latest_event_type IS NULL
            THEN 'NO EVENT HISTORY'

        WHEN expected_status = 'UNKNOWN'
            THEN 'UNKNOWN EVENT TYPE'

        WHEN current_status = expected_status
            THEN 'MATCH'

        ELSE 'MISMATCH'
    END AS status_check

FROM reconciliation

ORDER BY shipment_id;


USE logistics;

WITH shipment_times AS (
    SELECT
        shipment_id,

        MIN(CASE
            WHEN event_type = 'DISPATCHED'
            THEN event_timestamp
        END) AS dispatch_time,

        MIN(CASE
            WHEN event_type = 'DELIVERED'
            THEN event_timestamp
        END) AS delivery_time

    FROM shipment_events
    GROUP BY shipment_id
),

attempt_metrics AS (
    SELECT
        shipment_id,

        COUNT(*) AS total_attempts,

        SUM(CASE
            WHEN attempt_result = 'FAILED'
            THEN 1 ELSE 0
        END) AS failed_attempts

    FROM delivery_attempts
    GROUP BY shipment_id
),

shipment_metrics AS (
    SELECT
        s.shipment_id,
        c.carrier_id,
        c.carrier_name,
        s.current_status,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
            THEN 1 ELSE 0
        END AS valid_delivery_flag,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
             AND st.delivery_time <= s.promised_delivery_at
            THEN 1 ELSE 0
        END AS on_time_flag,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
             AND st.delivery_time > s.promised_delivery_at
            THEN 1 ELSE 0
        END AS late_flag,

        CASE
            WHEN s.current_status = 'DELIVERED'
             AND st.dispatch_time IS NOT NULL
             AND st.delivery_time IS NOT NULL
             AND st.delivery_time >= st.dispatch_time
            THEN TIMESTAMPDIFF(
                MINUTE,
                st.dispatch_time,
                st.delivery_time
            ) / 60.0
        END AS delivery_duration_hours,

        COALESCE(am.failed_attempts, 0) AS failed_attempts

    FROM shipments s

    JOIN carriers c
        ON s.carrier_id = c.carrier_id

    LEFT JOIN shipment_times st
        ON s.shipment_id = st.shipment_id

    LEFT JOIN attempt_metrics am
        ON s.shipment_id = am.shipment_id
),

carrier_report AS (
    SELECT
        carrier_id,
        carrier_name,

        COUNT(*) AS total_shipments,

        SUM(valid_delivery_flag) AS valid_completed_deliveries,

        SUM(on_time_flag) AS on_time_shipments,

        SUM(late_flag) AS late_shipments,

        ROUND(
            100.0 * SUM(on_time_flag) /
            NULLIF(SUM(valid_delivery_flag), 0),
            2
        ) AS sla_compliance_percentage,

        ROUND(
            AVG(delivery_duration_hours),
            2
        ) AS avg_delivery_hours,

        SUM(
            CASE
                WHEN current_status = 'FAILED'
                THEN 1 ELSE 0
            END
        ) AS failed_shipments,

        ROUND(
            100.0 * SUM(
                CASE
                    WHEN current_status = 'FAILED'
                    THEN 1 ELSE 0
                END
            ) / COUNT(*),
            2
        ) AS failed_shipment_rate,

        SUM(failed_attempts) AS total_failed_attempts,

        SUM(
            CASE
                WHEN failed_attempts > 1
                THEN 1 ELSE 0
            END
        ) AS multiple_failed_attempt_shipments

    FROM shipment_metrics

    GROUP BY carrier_id, carrier_name
)

SELECT
    *,

    CASE
        WHEN valid_completed_deliveries = 0
            THEN 'Review missing delivery records and investigate failed shipments'

        WHEN sla_compliance_percentage < 90
             AND multiple_failed_attempt_shipments > 0
            THEN 'Improve SLA performance and investigate repeated delivery failures'

        WHEN sla_compliance_percentage < 90
            THEN 'Improve route planning and reduce delivery delays'

        WHEN multiple_failed_attempt_shipments > 0
            THEN 'Maintain SLA performance but investigate repeated failed attempts'

        WHEN total_failed_attempts > 0
            THEN 'Improve first-attempt delivery success'

        ELSE 'Maintain current delivery performance'
    END AS improvement_recommendation

FROM carrier_report

ORDER BY sla_compliance_percentage IS NULL,
         sla_compliance_percentage ASC;
         
         




