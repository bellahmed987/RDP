-- Keep existing recipient reviews and allow the donor to leave a separate review.
SET @has_ratings = (
  SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'ratings'
);

SET @ddl = IF(@has_ratings > 0 AND NOT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ratings' AND column_name = 'reviewer_id'
), 'ALTER TABLE ratings ADD COLUMN reviewer_id BIGINT NULL', 'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(@has_ratings > 0 AND NOT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ratings' AND column_name = 'target_id'
), 'ALTER TABLE ratings ADD COLUMN target_id BIGINT NULL', 'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(@has_ratings > 0,
  'UPDATE ratings SET reviewer_id = recipient_id, target_id = donor_id WHERE reviewer_id IS NULL OR target_id IS NULL',
  'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(@has_ratings > 0 AND (EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ratings' AND column_name = 'reviewer_id' AND is_nullable = 'YES'
  ) OR EXISTS (
   SELECT 1 FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'ratings' AND column_name = 'target_id' AND is_nullable = 'YES'
  )), 'ALTER TABLE ratings MODIFY reviewer_id BIGINT NOT NULL, MODIFY target_id BIGINT NOT NULL', 'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(@has_ratings > 0 AND EXISTS (
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'ratings' AND index_name = 'uq_rating_request'
), 'ALTER TABLE ratings DROP INDEX uq_rating_request', 'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(@has_ratings > 0 AND NOT EXISTS (
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'ratings' AND index_name = 'uq_rating_request_reviewer'
), 'ALTER TABLE ratings ADD CONSTRAINT uq_rating_request_reviewer UNIQUE (request_id, reviewer_id)', 'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
