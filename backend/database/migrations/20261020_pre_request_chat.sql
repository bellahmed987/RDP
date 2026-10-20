-- Allow a recipient to start one conversation per listing before creating a request.
-- This migration is safe to run before the first Hibernate schema is created.
SET @has_conversations = (
  SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
);

SET @request_not_nullable = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND column_name = 'request_id' AND is_nullable = 'NO'
);
SET @request_fk = (
  SELECT constraint_name FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND column_name = 'request_id' AND referenced_table_name IS NOT NULL
  LIMIT 1
);
SET @ddl = IF(@has_conversations > 0 AND @request_not_nullable > 0 AND @request_fk IS NOT NULL,
  CONCAT('ALTER TABLE conversations DROP FOREIGN KEY `', @request_fk, '`'),
  'SELECT 1');
PREPARE chat_migration FROM @ddl;
EXECUTE chat_migration;
DEALLOCATE PREPARE chat_migration;

SET @ddl = IF(@has_conversations > 0 AND @request_not_nullable > 0,
  'ALTER TABLE conversations MODIFY COLUMN request_id BIGINT NULL',
  'SELECT 1');
PREPARE chat_migration FROM @ddl;
EXECUTE chat_migration;
DEALLOCATE PREPARE chat_migration;

SET @has_request_fk = (
  SELECT COUNT(*) FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND column_name = 'request_id' AND referenced_table_name = 'donation_requests'
);
SET @ddl = IF(@has_conversations > 0 AND @has_request_fk = 0,
  'ALTER TABLE conversations ADD CONSTRAINT fk_conversations_request FOREIGN KEY (request_id) REFERENCES donation_requests(id)',
  'SELECT 1');
PREPARE chat_migration FROM @ddl;
EXECUTE chat_migration;
DEALLOCATE PREPARE chat_migration;

SET @has_donation_id = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'conversations' AND column_name = 'donation_id'
);
SET @ddl = IF(@has_conversations > 0 AND @has_donation_id = 0,
  'ALTER TABLE conversations ADD COLUMN donation_id BIGINT NULL',
  'SELECT 1');
PREPARE chat_migration FROM @ddl;
EXECUTE chat_migration;
DEALLOCATE PREPARE chat_migration;

SET @has_donation_fk = (
  SELECT COUNT(*) FROM information_schema.referential_constraints
  WHERE constraint_schema = DATABASE() AND table_name = 'conversations'
    AND constraint_name = 'fk_conversations_donation'
);
SET @ddl = IF(@has_conversations > 0 AND @has_donation_fk = 0,
  'ALTER TABLE conversations ADD CONSTRAINT fk_conversations_donation FOREIGN KEY (donation_id) REFERENCES donations(id)',
  'SELECT 1');
PREPARE chat_migration FROM @ddl;
EXECUTE chat_migration;
DEALLOCATE PREPARE chat_migration;

SET @has_contact_key = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND index_name = 'uq_conversation_donation_recipient'
);
SET @ddl = IF(@has_conversations > 0 AND @has_contact_key = 0,
  'ALTER TABLE conversations ADD CONSTRAINT uq_conversation_donation_recipient UNIQUE (donation_id, recipient_id)',
  'SELECT 1');
PREPARE chat_migration FROM @ddl;
EXECUTE chat_migration;
DEALLOCATE PREPARE chat_migration;
