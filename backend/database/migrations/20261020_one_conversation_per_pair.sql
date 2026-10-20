-- Keep one shared chat history for each donor/recipient pair, even across listings.
SET @has_conversations = (
  SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
);

SET @ddl = IF(@has_conversations > 0,
  'CREATE TEMPORARY TABLE tmp_conversation_merge_map AS
   SELECT c.id AS duplicate_id, pairs.keep_id
   FROM conversations c
   JOIN (
     SELECT donor_id, recipient_id, MIN(id) AS keep_id
     FROM conversations
     GROUP BY donor_id, recipient_id
     HAVING COUNT(*) > 1
   ) pairs ON pairs.donor_id = c.donor_id AND pairs.recipient_id = c.recipient_id
   WHERE c.id <> pairs.keep_id',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @has_messages = (
  SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'messages'
);
SET @ddl = IF(@has_conversations > 0 AND @has_messages > 0,
  'UPDATE messages m
   JOIN tmp_conversation_merge_map merge_map ON merge_map.duplicate_id = m.conversation_id
   SET m.conversation_id = merge_map.keep_id',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @ddl = IF(@has_conversations > 0,
  'UPDATE conversations c
   JOIN tmp_conversation_merge_map merge_map ON merge_map.duplicate_id = c.id
   SET c.request_id = NULL',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @ddl = IF(@has_conversations > 0,
  'DELETE c FROM conversations c
   JOIN tmp_conversation_merge_map merge_map ON merge_map.duplicate_id = c.id',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @has_listing_unique = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND index_name = 'uq_conversation_donation_recipient'
);
SET @dependent_fks = (
  SELECT GROUP_CONCAT(DISTINCT CONCAT('DROP FOREIGN KEY `', constraint_name, '`') SEPARATOR ', ')
  FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND ((column_name = 'recipient_id' AND referenced_table_name = 'users')
      OR (column_name = 'donation_id' AND referenced_table_name = 'donations'))
);
SET @ddl = IF(@has_listing_unique > 0 AND @dependent_fks IS NOT NULL,
  CONCAT('ALTER TABLE conversations ', @dependent_fks),
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @ddl = IF(@has_listing_unique > 0,
  'ALTER TABLE conversations DROP INDEX uq_conversation_donation_recipient',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @has_recipient_fk = (
  SELECT COUNT(*) FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND column_name = 'recipient_id' AND referenced_table_name = 'users'
);
SET @ddl = IF(@has_conversations > 0 AND @has_recipient_fk = 0,
  'ALTER TABLE conversations ADD CONSTRAINT fk_conversations_recipient FOREIGN KEY (recipient_id) REFERENCES users(id)',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @has_donation_fk = (
  SELECT COUNT(*) FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND column_name = 'donation_id' AND referenced_table_name = 'donations'
);
SET @ddl = IF(@has_conversations > 0 AND @has_donation_fk = 0,
  'ALTER TABLE conversations ADD CONSTRAINT fk_conversations_donation_pair FOREIGN KEY (donation_id) REFERENCES donations(id)',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

SET @has_pair_unique = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'conversations'
    AND index_name = 'uq_conversation_donor_recipient'
);
SET @ddl = IF(@has_conversations > 0 AND @has_pair_unique = 0,
  'ALTER TABLE conversations ADD CONSTRAINT uq_conversation_donor_recipient UNIQUE (donor_id, recipient_id)',
  'SELECT 1');
PREPARE pair_migration FROM @ddl;
EXECUTE pair_migration;
DEALLOCATE PREPARE pair_migration;

DROP TEMPORARY TABLE IF EXISTS tmp_conversation_merge_map;
