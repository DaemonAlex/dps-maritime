-- ============================================
-- dps-maritime - Jetsam Company
-- Database Schema
-- ============================================

-- Player progression and stats
CREATE TABLE IF NOT EXISTS `maritime_players` (
    `identifier` VARCHAR(50) NOT NULL,
    `xp` INT DEFAULT 0,
    `level` INT DEFAULT 1,
    `boat_deliveries` INT DEFAULT 0,
    `dock_deliveries` INT DEFAULT 0,
    `total_earnings` BIGINT DEFAULT 0,
    `current_streak` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Delivery history
CREATE TABLE IF NOT EXISTS `maritime_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `job_type` ENUM('boat', 'dock') DEFAULT 'boat',
    `cargo_type` VARCHAR(50) DEFAULT NULL,
    `start_port` VARCHAR(50) DEFAULT NULL,
    `end_port` VARCHAR(50) DEFAULT NULL,
    `distance` INT DEFAULT 0,
    `payout` INT DEFAULT 0,
    `xp_earned` INT DEFAULT 0,
    `boat_used` VARCHAR(50) DEFAULT NULL,
    `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_job_type` (`job_type`),
    INDEX `idx_completed_at` (`completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player fleet (owned boats)
CREATE TABLE IF NOT EXISTS `maritime_fleet` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `owner` VARCHAR(50) NOT NULL,
    `model` VARCHAR(50) NOT NULL,
    `name` VARCHAR(50) DEFAULT NULL,
    `plate` VARCHAR(12) DEFAULT NULL,
    `fuel` FLOAT DEFAULT 100,
    `condition` INT DEFAULT 100,
    `is_spawned` TINYINT(1) DEFAULT 0,
    `is_impounded` TINYINT(1) DEFAULT 0,
    `impound_time` TIMESTAMP NULL DEFAULT NULL,
    `service_hours` INT DEFAULT 0,
    `last_service` TIMESTAMP NULL DEFAULT NULL,
    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_owner` (`owner`),
    INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migration for existing tables (run separately if needed)
-- ALTER TABLE `maritime_fleet` ADD COLUMN IF NOT EXISTS `plate` VARCHAR(12) DEFAULT NULL;
-- ALTER TABLE `maritime_fleet` ADD COLUMN IF NOT EXISTS `is_spawned` TINYINT(1) DEFAULT 0;
-- ALTER TABLE `maritime_fleet` ADD COLUMN IF NOT EXISTS `is_impounded` TINYINT(1) DEFAULT 0;
-- ALTER TABLE `maritime_fleet` ADD COLUMN IF NOT EXISTS `impound_time` TIMESTAMP NULL DEFAULT NULL;
-- ALTER TABLE `maritime_fleet` ADD COLUMN IF NOT EXISTS `service_hours` INT DEFAULT 0;
-- ALTER TABLE `maritime_fleet` ADD COLUMN IF NOT EXISTS `last_service` TIMESTAMP NULL DEFAULT NULL;
-- ALTER TABLE `maritime_fleet` ADD INDEX IF NOT EXISTS `idx_plate` (`plate`);

-- Placed containers (for dock work stacking)
CREATE TABLE IF NOT EXISTS `maritime_containers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT DEFAULT 0,
    `placed_by` VARCHAR(50) DEFAULT NULL,
    `placed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_placed_by` (`placed_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Leaderboard view (optional)
CREATE OR REPLACE VIEW `maritime_leaderboard` AS
SELECT
    `identifier`,
    `level`,
    `xp`,
    `boat_deliveries`,
    `dock_deliveries`,
    (`boat_deliveries` + `dock_deliveries`) AS `total_deliveries`,
    `total_earnings`
FROM `maritime_players`
ORDER BY `xp` DESC
LIMIT 100;
