create database logistics;
use logistics;
CREATE TABLE IF NOT EXISTS regions (
    region_id INT AUTO_INCREMENT PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    region_id INT,
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
);
CREATE TABLE IF NOT EXISTS customer_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    order_value DECIMAL(10,2),
    order_status VARCHAR(30),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
CREATE TABLE IF NOT EXISTS carriers (
    carrier_id INT AUTO_INCREMENT PRIMARY KEY,
    carrier_name VARCHAR(100) NOT NULL,
    contact_phone VARCHAR(20)
);
CREATE TABLE IF NOT EXISTS hubs (
    hub_id INT AUTO_INCREMENT PRIMARY KEY,
    hub_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    region_id INT,
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
);
CREATE TABLE IF NOT EXISTS routes (
    route_id INT AUTO_INCREMENT PRIMARY KEY,
    origin_hub_id INT NOT NULL,
    destination_hub_id INT NOT NULL,
    estimated_transit_hours DECIMAL(6,2),
    FOREIGN KEY (origin_hub_id) REFERENCES hubs(hub_id),
    FOREIGN KEY (destination_hub_id) REFERENCES hubs(hub_id)
);
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    carrier_id INT NOT NULL,
    route_id INT NOT NULL,
    shipment_type VARCHAR(30),
    current_status ENUM(
        'CREATED',
        'IN_TRANSIT',
        'OUT_FOR_DELIVERY',
        'DELIVERED',
        'FAILED',
        'CANCELLED',
        'RETURNED',
        'EXCEPTION'
    ) DEFAULT 'CREATED',
    estimated_delivery_at DATETIME,
    promised_delivery_at DATETIME NOT NULL,
    FOREIGN KEY (order_id) REFERENCES customer_orders(order_id),
    FOREIGN KEY (carrier_id) REFERENCES carriers(carrier_id),
    FOREIGN KEY (route_id) REFERENCES routes(route_id)
);
CREATE TABLE IF NOT EXISTS shipment_events (
    event_id INT AUTO_INCREMENT PRIMARY KEY,
    shipment_id INT NOT NULL,
    event_type ENUM(
        'CREATED',
        'DISPATCHED',
        'HUB_ARRIVAL',
        'HUB_DEPARTURE',
        'OUT_FOR_DELIVERY',
        'DELIVERY_ATTEMPT_FAILED',
        'DELIVERED',
        'DELIVERY_FAILED',
        'EXCEPTION',
        'RETURNED',
        'CANCELLED'
    ) NOT NULL,
    event_timestamp DATETIME NOT NULL,
    hub_id INT,
    source_event_id VARCHAR(100),
    event_notes TEXT,
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    FOREIGN KEY (hub_id) REFERENCES hubs(hub_id)
);
CREATE TABLE IF NOT EXISTS delivery_attempts (
    attempt_id INT AUTO_INCREMENT PRIMARY KEY,
    shipment_id INT NOT NULL,
    attempt_number INT NOT NULL,
    attempt_timestamp DATETIME NOT NULL,
    attempt_result ENUM('SUCCESS', 'FAILED') NOT NULL,
    failure_reason VARCHAR(255),
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id),
    UNIQUE (shipment_id, attempt_number)
);
show tables;


INSERT INTO regions (region_id, region_name) VALUES
(1, 'Hyderabad'),
(2, 'Chennai'),
(3, 'Bengaluru'),
(4, 'pune'),
(5, 'delhi');

INSERT INTO customers
(customer_id, customer_name, city, region_id) VALUES
(1, 'Ravi', 'Hyderabad', 1),
(2, 'Priya', 'Chennai', 2),
(3, 'Arjun', 'Bengaluru', 3),
(4, 'Sita', 'pune', 4),
(5, 'Kiran', 'Hyderabad', 1),
(6, 'Meena', 'Chennai', 2),
(7, 'Naveen', 'Bengaluru', 3),
(8, 'Anu', 'Vizag', 4);

INSERT INTO customer_orders
(order_id, customer_id, order_date, order_value, order_status) VALUES
(1001, 1, '2026-11-02 07:00:00', 12000, 'DELIVERED'),
(1002, 2, '2026-11-02 08:00:00', 8500, 'DELIVERED'),
(1003, 3, '2026-11-03 07:00:00', 15000, 'IN_TRANSIT'),
(1004, 4, '2026-11-02 06:00:00', 6500, 'FAILED'),
(1005, 5, '2026-11-01 08:00:00', 9200, 'DELIVERED'),
(1006, 6, '2026-11-01 06:30:00', 11000, 'DELIVERED'),
(1007, 7, '2026-11-03 08:00:00', 7000, 'IN_TRANSIT'),
(1008, 8, '2026-11-03 06:00:00', 13500, 'DELIVERED');

INSERT INTO carriers
(carrier_id, carrier_name, contact_phone) VALUES
(1, 'Flipkart', '9876543210'),
(2, 'Meesho', '9876543211'),
(3, 'Amazon', '9876543212');

INSERT INTO hubs
(hub_id, hub_name, city, region_id) VALUES
(1, 'Hyderabad Central Hub', 'Hyderabad', 1),
(2, 'Pune Hub', 'Pune', 4),
(3, 'Chennai Hub', 'Chennai', 2),
(4, 'Bengaluru Hub', 'Bengaluru', 3),
(5, 'Vizag Hub', 'Vizag', 4);

INSERT INTO routes
(route_id, origin_hub_id, destination_hub_id,
 estimated_transit_hours) VALUES
(1, 1, 2, 6.00),
(2, 3, 4, 7.00),
(3, 1, 3, 10.00),
(4, 4, 1, 8.00),
(5, 2, 1, 6.00);

INSERT INTO shipments
(shipment_id, order_id, carrier_id, route_id,
 shipment_type, current_status,
 estimated_delivery_at, promised_delivery_at) VALUES
(101, 1001, 1, 1, 'STANDARD', 'DELIVERED',
 '2026-11-02 16:30:00', '2026-11-02 18:00:00'),

(102, 1002, 2, 2, 'EXPRESS', 'DELIVERED',
 '2026-11-02 16:00:00', '2026-11-02 16:30:00'),

(103, 1003, 1, 3, 'STANDARD', 'OUT_FOR_DELIVERY',
 '2026-11-03 17:00:00', '2026-11-03 18:00:00'),

(104, 1004, 3, 4, 'SAME_DAY', 'FAILED',
 '2026-11-02 13:00:00', '2026-11-02 14:00:00'),

(105, 1005, 2, 5, 'STANDARD', 'DELIVERED',
 '2026-11-01 12:00:00', '2026-11-01 13:00:00'),

(106, 1006, 3, 1, 'EXPRESS', 'DELIVERED',
 '2026-11-01 09:00:00', '2026-11-01 08:00:00'),

(107, 1007, 1, 2, 'STANDARD', 'IN_TRANSIT',
 '2026-11-03 17:00:00', '2026-11-03 18:00:00'),

(108, 1008, 2, 3, 'SAME_DAY', 'DELIVERED',
 '2026-11-03 12:00:00', '2026-11-03 12:00:00');
 
 INSERT INTO shipment_events
(shipment_id, event_type, event_timestamp, hub_id,
 source_event_id, event_notes) VALUES

-- Shipment 101: successful on-time delivery
(101, 'CREATED', '2026-11-02 07:00:00', 1, 'E101A', 'Order created'),
(101, 'DISPATCHED', '2026-11-02 08:00:00', 1, 'E101B', 'Shipment dispatched'),
(101, 'HUB_DEPARTURE', '2026-11-02 09:00:00', 1, 'E101C', 'Left origin hub'),
(101, 'HUB_ARRIVAL', '2026-11-02 13:00:00', 2, 'E101D', 'Reached destination hub'),
(101, 'OUT_FOR_DELIVERY', '2026-11-02 15:00:00', 2, 'E101E', 'Out for delivery'),
(101, 'DELIVERED', '2026-11-02 17:00:00', 2, 'E101F', 'Delivered successfully'),

-- Shipment 102: late delivery after one failed attempt
(102, 'CREATED', '2026-11-02 08:00:00', 3, 'E102A', 'Order created'),
(102, 'DISPATCHED', '2026-11-02 09:00:00', 3, 'E102B', 'Shipment dispatched'),
(102, 'HUB_ARRIVAL', '2026-11-02 14:00:00', 4, 'E102C', 'Reached hub'),
(102, 'DELIVERY_ATTEMPT_FAILED', '2026-11-02 15:00:00', 4, 'E102D', 'Customer unavailable'),
(102, 'OUT_FOR_DELIVERY', '2026-11-02 16:00:00', 4, 'E102E', 'Second delivery attempt'),
(102, 'DELIVERED', '2026-11-02 18:30:00', 4, 'E102F', 'Delivered successfully'),

-- Shipment 103: delivery not completed and multiple failures
(103, 'CREATED', '2026-11-03 07:00:00', 1, 'E103A', 'Order created'),
(103, 'DISPATCHED', '2026-11-03 08:00:00', 1, 'E103B', 'Shipment dispatched'),
(103, 'HUB_ARRIVAL', '2026-11-03 12:00:00', 3, 'E103C', 'Reached hub'),
(103, 'OUT_FOR_DELIVERY', '2026-11-03 16:00:00', 3, 'E103D', 'Out for delivery'),
(103, 'DELIVERY_ATTEMPT_FAILED', '2026-11-03 17:00:00', 3, 'E103E', 'Customer unavailable'),

-- Shipment 104: failed delivery
(104, 'CREATED', '2026-11-02 06:00:00', 4, 'E104A', 'Order created'),
(104, 'DISPATCHED', '2026-11-02 07:00:00', 4, 'E104B', 'Shipment dispatched'),
(104, 'OUT_FOR_DELIVERY', '2026-11-02 10:00:00', 1, 'E104C', 'Out for delivery'),
(104, 'DELIVERY_ATTEMPT_FAILED', '2026-11-02 11:00:00', 1, 'E104D', 'Customer unavailable'),
(104, 'DELIVERY_ATTEMPT_FAILED', '2026-11-02 13:00:00', 1, 'E104E', 'Second attempt failed'),
(104, 'DELIVERY_FAILED', '2026-11-02 13:30:00', 1, 'E104F', 'Delivery failed'),

-- Shipment 105: delivery record without dispatch event
(105, 'CREATED', '2026-11-01 08:00:00', 2, 'E105A', 'Order created'),
(105, 'DELIVERED', '2026-11-01 12:00:00', 1, 'E105B', 'Delivered successfully'),

-- Shipment 106: deliberately incorrect chronology
(106, 'CREATED', '2026-11-01 06:30:00', 1, 'E106A', 'Order created'),
(106, 'DELIVERED', '2026-11-01 07:00:00', 2, 'E106B', 'Delivery recorded'),
(106, 'DISPATCHED', '2026-11-01 08:00:00', 1, 'E106C', 'Dispatch recorded later'),

-- Shipment 107: duplicate event and status mismatch
(107, 'CREATED', '2026-11-03 08:00:00', 3, 'E107A', 'Order created'),
(107, 'DISPATCHED', '2026-11-03 09:00:00', 3, 'E107B', 'Shipment dispatched'),
(107, 'HUB_ARRIVAL', '2026-11-03 11:00:00', 4, 'E107C', 'Reached hub'),
(107, 'HUB_ARRIVAL', '2026-11-03 11:00:00', 4, 'E107C', 'Duplicate event'),
(107, 'EXCEPTION', '2026-11-03 12:00:00', 4, 'E107D', 'Shipment exception'),

-- Shipment 108: late delivery
(108, 'CREATED', '2026-11-03 06:00:00', 1, 'E108A', 'Order created'),
(108, 'DISPATCHED', '2026-11-03 07:00:00', 1, 'E108B', 'Shipment dispatched'),
(108, 'HUB_ARRIVAL', '2026-11-03 11:00:00', 3, 'E108C', 'Reached hub'),
(108, 'OUT_FOR_DELIVERY', '2026-11-03 12:00:00', 3, 'E108D', 'Out for delivery'),
(108, 'DELIVERED', '2026-11-03 13:00:00', 3, 'E108E', 'Delivered successfully');

INSERT INTO delivery_attempts
(shipment_id, attempt_number, attempt_timestamp,
 attempt_result, failure_reason) VALUES

(101, 1, '2026-11-02 17:00:00', 'SUCCESS', NULL),

(102, 1, '2026-11-02 15:00:00', 'FAILED', 'Customer unavailable'),
(102, 2, '2026-11-02 18:30:00', 'SUCCESS', NULL),

(103, 1, '2026-11-03 16:30:00', 'FAILED', 'Customer unavailable'),
(103, 2, '2026-11-03 17:00:00', 'FAILED', 'Customer unavailable'),

(104, 1, '2026-11-02 11:00:00', 'FAILED', 'Wrong address'),
(104, 2, '2026-11-02 13:00:00', 'FAILED', 'Customer unavailable'),

(105, 1, '2026-11-01 12:00:00', 'SUCCESS', NULL),

(106, 1, '2026-11-01 07:00:00', 'SUCCESS', NULL),

(108, 1, '2026-11-03 13:00:00', 'SUCCESS', NULL);


