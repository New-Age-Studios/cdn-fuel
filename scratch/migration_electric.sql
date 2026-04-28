ALTER TABLE `fuel_stations` 
ADD COLUMN `electric_consumed` float DEFAULT 0,
ADD COLUMN `electric_bill_due` datetime DEFAULT NULL,
ADD COLUMN `electric_debt` int(11) DEFAULT 0,
ADD COLUMN `electric_loyalty_level` int(11) DEFAULT 0,
ADD COLUMN `electric_status` tinyint(1) DEFAULT 1;
