-- ==============================================================================
-- WACRM - WhatsApp CRM Complete MySQL / MariaDB Schema (XAMPP Compatible)
-- Converted from Supabase PostgreSQL (42 Migrations Consolidated)
-- Target Environment: MySQL 8.0+ / MariaDB 10.4+ (XAMPP Default)
-- ==============================================================================

-- 1. Create and Select Database
-- CREATE DATABASE IF NOT EXISTS `wacrm`
--   CHARACTER SET utf8mb4
--   COLLATE utf8mb4_unicode_ci;

-- USE `wacrm`;

-- Disable foreign key checks for clean setup
SET FOREIGN_KEY_CHECKS = 0;

-- ==============================================================================
-- 2. USERS (Replaces Supabase auth.users)
-- ==============================================================================
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` VARCHAR(36) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `raw_user_meta_data` JSON DEFAULT NULL,
  `email_confirmed_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 3. ACCOUNTS (Multi-tenancy foundation)
-- ==============================================================================
DROP TABLE IF EXISTS `accounts`;
CREATE TABLE `accounts` (
  `id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `owner_user_id` VARCHAR(36) NOT NULL,
  `default_currency` VARCHAR(3) NOT NULL DEFAULT 'USD',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_accounts_owner_user_id` (`owner_user_id`),
  CONSTRAINT `fk_accounts_owner` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 4. ACCOUNT INVITATIONS
-- ==============================================================================
DROP TABLE IF EXISTS `account_invitations`;
CREATE TABLE `account_invitations` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `token_hash` VARCHAR(255) NOT NULL,
  `role` ENUM('admin', 'agent', 'viewer') NOT NULL DEFAULT 'agent',
  `created_by_user_id` VARCHAR(36) DEFAULT NULL,
  `label` VARCHAR(255) DEFAULT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `accepted_at` DATETIME(3) DEFAULT NULL,
  `accepted_by_user_id` VARCHAR(36) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_invitations_token_hash` (`token_hash`),
  KEY `idx_invitations_account_pending` (`account_id`, `expires_at`, `accepted_at`),
  CONSTRAINT `fk_invitations_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_invitations_creator` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_invitations_acceptor` FOREIGN KEY (`accepted_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 5. PROFILES
-- ==============================================================================
DROP TABLE IF EXISTS `profiles`;
CREATE TABLE `profiles` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) DEFAULT NULL,
  `account_role` ENUM('owner', 'admin', 'agent', 'viewer') DEFAULT 'owner',
  `full_name` VARCHAR(255) NOT NULL DEFAULT '',
  `email` VARCHAR(255) NOT NULL,
  `avatar_url` TEXT DEFAULT NULL,
  `role` VARCHAR(50) DEFAULT 'user',
  `beta_features` JSON DEFAULT (JSON_ARRAY()),
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_profiles_user_id` (`user_id`),
  KEY `idx_profiles_account_role` (`account_id`, `account_role`),
  CONSTRAINT `fk_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_profiles_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 6. CONTACTS
-- ==============================================================================
DROP TABLE IF EXISTS `contacts`;
CREATE TABLE `contacts` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `phone` VARCHAR(50) NOT NULL,
  `phone_normalized` VARCHAR(50) GENERATED ALWAYS AS (REGEXP_REPLACE(`phone`, '[^0-9]', '')) STORED,
  `wa_user_id` VARCHAR(255) DEFAULT NULL,
  `wa_parent_user_id` VARCHAR(255) DEFAULT NULL,
  `wa_username` VARCHAR(255) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `email` VARCHAR(255) DEFAULT NULL,
  `company` VARCHAR(255) DEFAULT NULL,
  `avatar_url` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_contacts_account_phone_norm` (`account_id`, `phone_normalized`),
  KEY `idx_contacts_account_id` (`account_id`),
  KEY `idx_contacts_user_id` (`user_id`),
  KEY `idx_contacts_wa_user_id` (`account_id`, `wa_user_id`),
  CONSTRAINT `fk_contacts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_contacts_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 7. TAGS
-- ==============================================================================
DROP TABLE IF EXISTS `tags`;
CREATE TABLE `tags` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `color` VARCHAR(20) NOT NULL DEFAULT '#3b82f6',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_tags_account` (`account_id`, `name`),
  KEY `idx_tags_user` (`user_id`),
  CONSTRAINT `fk_tags_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_tags_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 8. CONTACT TAGS (Many-to-Many)
-- ==============================================================================
DROP TABLE IF EXISTS `contact_tags`;
CREATE TABLE `contact_tags` (
  `id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) NOT NULL,
  `tag_id` VARCHAR(36) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_contact_tags_unique` (`contact_id`, `tag_id`),
  KEY `idx_contact_tags_tag` (`tag_id`),
  CONSTRAINT `fk_contact_tags_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_contact_tags_tag` FOREIGN KEY (`tag_id`) REFERENCES `tags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 9. CUSTOM FIELDS
-- ==============================================================================
DROP TABLE IF EXISTS `custom_fields`;
CREATE TABLE `custom_fields` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `field_name` VARCHAR(100) NOT NULL,
  `field_type` VARCHAR(50) NOT NULL DEFAULT 'text',
  `field_options` JSON DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_custom_fields_account` (`account_id`),
  CONSTRAINT `fk_custom_fields_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_custom_fields_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 10. CONTACT CUSTOM VALUES
-- ==============================================================================
DROP TABLE IF EXISTS `contact_custom_values`;
CREATE TABLE `contact_custom_values` (
  `id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) NOT NULL,
  `custom_field_id` VARCHAR(36) NOT NULL,
  `value` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_contact_custom_unique` (`contact_id`, `custom_field_id`),
  KEY `idx_contact_custom_field` (`custom_field_id`),
  CONSTRAINT `fk_contact_custom_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_contact_custom_field` FOREIGN KEY (`custom_field_id`) REFERENCES `custom_fields` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 11. CONTACT NOTES
-- ==============================================================================
DROP TABLE IF EXISTS `contact_notes`;
CREATE TABLE `contact_notes` (
  `id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `note_text` TEXT NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_contact_notes_contact` (`contact_id`),
  KEY `idx_contact_notes_account` (`account_id`),
  CONSTRAINT `fk_contact_notes_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_contact_notes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_contact_notes_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 12. CONVERSATIONS
-- ==============================================================================
DROP TABLE IF EXISTS `conversations`;
CREATE TABLE `conversations` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) NOT NULL,
  `status` ENUM('open', 'pending', 'closed') NOT NULL DEFAULT 'open',
  `assigned_agent_id` VARCHAR(36) DEFAULT NULL,
  `last_message_text` TEXT DEFAULT NULL,
  `last_message_at` DATETIME(3) DEFAULT NULL,
  `unread_count` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_conversations_account_contact` (`account_id`, `contact_id`),
  KEY `idx_conversations_account_status` (`account_id`, `status`, `last_message_at`),
  KEY `idx_conversations_user_id` (`user_id`),
  KEY `idx_conversations_assigned_agent` (`assigned_agent_id`),
  CONSTRAINT `fk_conversations_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_conversations_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_conversations_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_conversations_agent` FOREIGN KEY (`assigned_agent_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 13. MESSAGES
-- ==============================================================================
DROP TABLE IF EXISTS `messages`;
CREATE TABLE `messages` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `conversation_id` VARCHAR(36) NOT NULL,
  `sender_type` ENUM('customer', 'agent', 'bot') NOT NULL,
  `sender_id` VARCHAR(36) DEFAULT NULL,
  `content_type` ENUM('text', 'image', 'document', 'audio', 'video', 'location', 'template', 'interactive') NOT NULL DEFAULT 'text',
  `content_text` MEDIUMTEXT DEFAULT NULL,
  `media_url` TEXT DEFAULT NULL,
  `template_name` VARCHAR(255) DEFAULT NULL,
  `message_id` VARCHAR(255) DEFAULT NULL,
  `interactive_reply_id` VARCHAR(255) DEFAULT NULL,
  `interactive_payload` JSON DEFAULT NULL,
  `status` ENUM('sending', 'sent', 'delivered', 'read', 'failed') NOT NULL DEFAULT 'sent',
  `error_code` INT DEFAULT NULL,
  `error_title` VARCHAR(255) DEFAULT NULL,
  `error_details` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_messages_conversation_id` (`conversation_id`, `created_at`),
  KEY `idx_messages_message_id` (`message_id`),
  KEY `idx_messages_account_id` (`account_id`),
  CONSTRAINT `fk_messages_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 14. MESSAGE REACTIONS
-- ==============================================================================
DROP TABLE IF EXISTS `message_reactions`;
CREATE TABLE `message_reactions` (
  `id` VARCHAR(36) NOT NULL,
  `message_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) DEFAULT NULL,
  `emoji` VARCHAR(20) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_message_reactions_message` (`message_id`),
  CONSTRAINT `fk_message_reactions_message` FOREIGN KEY (`message_id`) REFERENCES `messages` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_message_reactions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 15. QUICK REPLIES
-- ==============================================================================
DROP TABLE IF EXISTS `quick_replies`;
CREATE TABLE `quick_replies` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `kind` ENUM('text', 'interactive') NOT NULL DEFAULT 'text',
  `content_text` MEDIUMTEXT DEFAULT NULL,
  `interactive_payload` JSON DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_quick_replies_account` (`account_id`),
  CONSTRAINT `fk_quick_replies_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_quick_replies_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 16. WHATSAPP CONFIG
-- ==============================================================================
DROP TABLE IF EXISTS `whatsapp_config`;
CREATE TABLE `whatsapp_config` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `phone_number_id` VARCHAR(255) NOT NULL,
  `waba_id` VARCHAR(255) DEFAULT NULL,
  `access_token` TEXT NOT NULL,
  `verify_token` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('connected', 'disconnected') NOT NULL DEFAULT 'disconnected',
  `connected_at` DATETIME(3) DEFAULT NULL,
  `business_name` VARCHAR(255) DEFAULT NULL,
  `display_phone_number` VARCHAR(50) DEFAULT NULL,
  `quality_rating` VARCHAR(50) DEFAULT NULL,
  `messaging_limit` VARCHAR(50) DEFAULT NULL,
  `sync_status` VARCHAR(50) DEFAULT NULL,
  `sync_error` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_whatsapp_config_account` (`account_id`),
  UNIQUE KEY `idx_whatsapp_config_phone_number_id` (`phone_number_id`),
  CONSTRAINT `fk_whatsapp_config_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_whatsapp_config_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 17. MESSAGE TEMPLATES
-- ==============================================================================
DROP TABLE IF EXISTS `message_templates`;
CREATE TABLE `message_templates` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `category` ENUM('Marketing', 'Utility', 'Authentication') NOT NULL DEFAULT 'Marketing',
  `language` VARCHAR(20) DEFAULT 'en_US',
  `header_type` ENUM('text', 'image', 'video', 'document') DEFAULT NULL,
  `header_content` TEXT DEFAULT NULL,
  `body_text` TEXT NOT NULL,
  `footer_text` TEXT DEFAULT NULL,
  `buttons` JSON DEFAULT NULL,
  `status` ENUM('Draft', 'Pending', 'Approved', 'Rejected') DEFAULT 'Draft',
  `meta_template_id` VARCHAR(255) DEFAULT NULL,
  `rejected_reason` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_message_templates_account` (`account_id`, `name`),
  CONSTRAINT `fk_message_templates_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_message_templates_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 18. PIPELINES
-- ==============================================================================
DROP TABLE IF EXISTS `pipelines`;
CREATE TABLE `pipelines` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_pipelines_account` (`account_id`),
  CONSTRAINT `fk_pipelines_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pipelines_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 19. PIPELINE STAGES
-- ==============================================================================
DROP TABLE IF EXISTS `pipeline_stages`;
CREATE TABLE `pipeline_stages` (
  `id` VARCHAR(36) NOT NULL,
  `pipeline_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `position` INT NOT NULL DEFAULT 0,
  `color` VARCHAR(20) NOT NULL DEFAULT '#3b82f6',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_pipeline_stages_pipeline` (`pipeline_id`, `position`),
  CONSTRAINT `fk_pipeline_stages_pipeline` FOREIGN KEY (`pipeline_id`) REFERENCES `pipelines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 20. DEALS
-- ==============================================================================
DROP TABLE IF EXISTS `deals`;
CREATE TABLE `deals` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `pipeline_id` VARCHAR(36) NOT NULL,
  `stage_id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) DEFAULT NULL,
  `conversation_id` VARCHAR(36) DEFAULT NULL,
  `title` VARCHAR(255) NOT NULL,
  `value` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `currency` VARCHAR(10) DEFAULT 'USD',
  `notes` TEXT DEFAULT NULL,
  `expected_close_date` DATE DEFAULT NULL,
  `status` VARCHAR(50) DEFAULT 'active',
  `position` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_deals_pipeline_stage` (`pipeline_id`, `stage_id`),
  KEY `idx_deals_account` (`account_id`),
  KEY `idx_deals_contact` (`contact_id`),
  CONSTRAINT `fk_deals_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_deals_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_deals_pipeline` FOREIGN KEY (`pipeline_id`) REFERENCES `pipelines` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_deals_stage` FOREIGN KEY (`stage_id`) REFERENCES `pipeline_stages` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_deals_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_deals_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 21. BROADCASTS
-- ==============================================================================
DROP TABLE IF EXISTS `broadcasts`;
CREATE TABLE `broadcasts` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `template_name` VARCHAR(255) NOT NULL,
  `template_language` VARCHAR(20) NOT NULL DEFAULT 'en_US',
  `template_variables` JSON DEFAULT NULL,
  `audience_filter` JSON DEFAULT NULL,
  `scheduled_at` DATETIME(3) DEFAULT NULL,
  `status` ENUM('draft', 'scheduled', 'sending', 'sent', 'failed') NOT NULL DEFAULT 'draft',
  `total_recipients` INT NOT NULL DEFAULT 0,
  `sent_count` INT NOT NULL DEFAULT 0,
  `delivered_count` INT NOT NULL DEFAULT 0,
  `read_count` INT NOT NULL DEFAULT 0,
  `replied_count` INT NOT NULL DEFAULT 0,
  `failed_count` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_broadcasts_account` (`account_id`, `status`),
  CONSTRAINT `fk_broadcasts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_broadcasts_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 22. BROADCAST RECIPIENTS
-- ==============================================================================
DROP TABLE IF EXISTS `broadcast_recipients`;
CREATE TABLE `broadcast_recipients` (
  `id` VARCHAR(36) NOT NULL,
  `broadcast_id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) DEFAULT NULL,
  `status` ENUM('pending', 'sent', 'delivered', 'read', 'replied', 'failed') NOT NULL DEFAULT 'pending',
  `sent_at` DATETIME(3) DEFAULT NULL,
  `delivered_at` DATETIME(3) DEFAULT NULL,
  `read_at` DATETIME(3) DEFAULT NULL,
  `replied_at` DATETIME(3) DEFAULT NULL,
  `error_message` TEXT DEFAULT NULL,
  `wamid` VARCHAR(255) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_broadcast_recipients_broadcast` (`broadcast_id`, `status`),
  KEY `idx_broadcast_recipients_wamid` (`wamid`),
  KEY `idx_broadcast_recipients_contact` (`contact_id`),
  CONSTRAINT `fk_broadcast_recipients_broadcast` FOREIGN KEY (`broadcast_id`) REFERENCES `broadcasts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_broadcast_recipients_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 23. AUTOMATIONS
-- ==============================================================================
DROP TABLE IF EXISTS `automations`;
CREATE TABLE `automations` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `trigger_type` VARCHAR(100) NOT NULL,
  `trigger_config` JSON NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT FALSE,
  `execution_count` INT NOT NULL DEFAULT 0,
  `last_executed_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_automations_account_trigger` (`account_id`, `trigger_type`, `is_active`),
  CONSTRAINT `fk_automations_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_automations_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 24. AUTOMATION STEPS
-- ==============================================================================
DROP TABLE IF EXISTS `automation_steps`;
CREATE TABLE `automation_steps` (
  `id` VARCHAR(36) NOT NULL,
  `automation_id` VARCHAR(36) NOT NULL,
  `parent_step_id` VARCHAR(36) DEFAULT NULL,
  `branch` ENUM('yes', 'no') DEFAULT NULL,
  `step_type` VARCHAR(100) NOT NULL,
  `step_config` JSON NOT NULL,
  `position` INT NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_automation_steps_automation` (`automation_id`, `position`),
  KEY `idx_automation_steps_parent` (`parent_step_id`),
  CONSTRAINT `fk_automation_steps_automation` FOREIGN KEY (`automation_id`) REFERENCES `automations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_automation_steps_parent` FOREIGN KEY (`parent_step_id`) REFERENCES `automation_steps` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 25. AUTOMATION LOGS
-- ==============================================================================
DROP TABLE IF EXISTS `automation_logs`;
CREATE TABLE `automation_logs` (
  `id` VARCHAR(36) NOT NULL,
  `automation_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) DEFAULT NULL,
  `trigger_event` VARCHAR(100) NOT NULL,
  `steps_executed` JSON NOT NULL,
  `status` ENUM('success', 'partial', 'failed') NOT NULL,
  `error_message` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_automation_logs_account` (`account_id`, `created_at`),
  KEY `idx_automation_logs_automation` (`automation_id`, `created_at`),
  CONSTRAINT `fk_automation_logs_automation` FOREIGN KEY (`automation_id`) REFERENCES `automations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_automation_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_automation_logs_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_automation_logs_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 26. AUTOMATION PENDING EXECUTIONS
-- ==============================================================================
DROP TABLE IF EXISTS `automation_pending_executions`;
CREATE TABLE `automation_pending_executions` (
  `id` VARCHAR(36) NOT NULL,
  `automation_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) DEFAULT NULL,
  `log_id` VARCHAR(36) DEFAULT NULL,
  `parent_step_id` VARCHAR(36) DEFAULT NULL,
  `branch` ENUM('yes', 'no') DEFAULT NULL,
  `next_step_position` INT NOT NULL,
  `context` JSON NOT NULL,
  `status` ENUM('pending', 'running', 'done', 'failed') NOT NULL DEFAULT 'pending',
  `run_at` DATETIME(3) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_automation_pending_due` (`run_at`, `status`),
  CONSTRAINT `fk_auto_pending_automation` FOREIGN KEY (`automation_id`) REFERENCES `automations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_auto_pending_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_auto_pending_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_auto_pending_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_auto_pending_log` FOREIGN KEY (`log_id`) REFERENCES `automation_logs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 27. FLOWS
-- ==============================================================================
DROP TABLE IF EXISTS `flows`;
CREATE TABLE `flows` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `status` ENUM('draft', 'active', 'archived') NOT NULL DEFAULT 'draft',
  `trigger_type` ENUM('keyword', 'first_inbound_message', 'manual') NOT NULL,
  `trigger_config` JSON NOT NULL,
  `entry_node_id` VARCHAR(255) DEFAULT NULL,
  `fallback_policy` JSON NOT NULL,
  `execution_count` INT NOT NULL DEFAULT 0,
  `last_executed_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_flows_account_active` (`account_id`, `trigger_type`, `status`),
  CONSTRAINT `fk_flows_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_flows_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 28. FLOW NODES
-- ==============================================================================
DROP TABLE IF EXISTS `flow_nodes`;
CREATE TABLE `flow_nodes` (
  `id` VARCHAR(36) NOT NULL,
  `flow_id` VARCHAR(36) NOT NULL,
  `node_key` VARCHAR(100) NOT NULL,
  `node_type` ENUM('start', 'send_buttons', 'send_list', 'send_message', 'collect_input', 'condition', 'set_tag', 'handoff', 'http_fetch', 'end') NOT NULL,
  `config` JSON NOT NULL,
  `position_x` INT NOT NULL DEFAULT 0,
  `position_y` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_flow_nodes_key` (`flow_id`, `node_key`),
  CONSTRAINT `fk_flow_nodes_flow` FOREIGN KEY (`flow_id`) REFERENCES `flows` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 29. FLOW RUNS
-- ==============================================================================
DROP TABLE IF EXISTS `flow_runs`;
CREATE TABLE `flow_runs` (
  `id` VARCHAR(36) NOT NULL,
  `flow_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `contact_id` VARCHAR(36) DEFAULT NULL,
  `current_node_id` VARCHAR(255) DEFAULT NULL,
  `state` JSON NOT NULL,
  `status` ENUM('active', 'completed', 'failed', 'abandoned', 'handed_off') NOT NULL DEFAULT 'active',
  `variables` JSON NOT NULL,
  `reprompt_count` INT NOT NULL DEFAULT 0,
  `last_interaction_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `completed_at` DATETIME(3) DEFAULT NULL,
  `error_message` TEXT DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_flow_runs_account_contact` (`account_id`, `contact_id`, `status`),
  CONSTRAINT `fk_flow_runs_flow` FOREIGN KEY (`flow_id`) REFERENCES `flows` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_flow_runs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_flow_runs_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_flow_runs_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 30. FLOW RUN EVENTS
-- ==============================================================================
DROP TABLE IF EXISTS `flow_run_events`;
CREATE TABLE `flow_run_events` (
  `id` VARCHAR(36) NOT NULL,
  `flow_run_id` VARCHAR(36) NOT NULL,
  `node_id` VARCHAR(255) DEFAULT NULL,
  `event_type` VARCHAR(100) NOT NULL,
  `payload` JSON NOT NULL,
  `meta_message_id` VARCHAR(255) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_flow_run_events_run` (`flow_run_id`, `created_at`),
  CONSTRAINT `fk_flow_run_events_run` FOREIGN KEY (`flow_run_id`) REFERENCES `flow_runs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 31. MEMBER PRESENCE
-- ==============================================================================
DROP TABLE IF EXISTS `member_presence`;
CREATE TABLE `member_presence` (
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'online',
  `last_seen_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`user_id`, `account_id`),
  CONSTRAINT `fk_presence_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_presence_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 32. API KEYS
-- ==============================================================================
DROP TABLE IF EXISTS `api_keys`;
CREATE TABLE `api_keys` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `key_hash` VARCHAR(255) NOT NULL,
  `key_prefix` VARCHAR(20) NOT NULL,
  `scopes` JSON NOT NULL,
  `created_by_user_id` VARCHAR(36) DEFAULT NULL,
  `expires_at` DATETIME(3) DEFAULT NULL,
  `last_used_at` DATETIME(3) DEFAULT NULL,
  `revoked_at` DATETIME(3) DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_api_keys_hash` (`key_hash`),
  KEY `idx_api_keys_account` (`account_id`),
  CONSTRAINT `fk_api_keys_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_api_keys_creator` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 33. NOTIFICATIONS
-- ==============================================================================
DROP TABLE IF EXISTS `notifications`;
CREATE TABLE `notifications` (
  `id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `type` VARCHAR(100) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `message` TEXT NOT NULL,
  `link` VARCHAR(500) DEFAULT NULL,
  `is_read` BOOLEAN NOT NULL DEFAULT FALSE,
  `read_at` DATETIME(3) DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user_unread` (`user_id`, `is_read`, `created_at`),
  KEY `idx_notifications_account` (`account_id`),
  CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_notifications_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 34. WEBHOOK ENDPOINTS
-- ==============================================================================
DROP TABLE IF EXISTS `webhook_endpoints`;
CREATE TABLE `webhook_endpoints` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `created_by` VARCHAR(36) DEFAULT NULL,
  `url` TEXT NOT NULL,
  `secret` TEXT NOT NULL,
  `events` JSON NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `last_delivery_at` DATETIME(3) DEFAULT NULL,
  `failure_count` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_webhook_endpoints_account` (`account_id`),
  CONSTRAINT `fk_webhook_endpoints_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_webhook_endpoints_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 35. AI CONFIGS
-- ==============================================================================
DROP TABLE IF EXISTS `ai_configs`;
CREATE TABLE `ai_configs` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `is_enabled` BOOLEAN NOT NULL DEFAULT FALSE,
  `provider` VARCHAR(50) NOT NULL DEFAULT 'openai',
  `model_name` VARCHAR(100) NOT NULL DEFAULT 'gpt-4o',
  `api_key` TEXT DEFAULT NULL,
  `embeddings_api_key` TEXT DEFAULT NULL,
  `system_prompt` TEXT DEFAULT NULL,
  `auto_reply_enabled` BOOLEAN NOT NULL DEFAULT FALSE,
  `auto_reply_delay_seconds` INT NOT NULL DEFAULT 5,
  `confidence_threshold` DECIMAL(3,2) NOT NULL DEFAULT 0.70,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ai_configs_account` (`account_id`),
  CONSTRAINT `fk_ai_configs_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 36. AI KNOWLEDGE DOCUMENTS
-- ==============================================================================
DROP TABLE IF EXISTS `ai_knowledge_documents`;
CREATE TABLE `ai_knowledge_documents` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `created_by` VARCHAR(36) DEFAULT NULL,
  `title` VARCHAR(255) NOT NULL,
  `content` MEDIUMTEXT NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_ai_documents_account` (`account_id`),
  CONSTRAINT `fk_ai_documents_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ai_documents_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 37. AI KNOWLEDGE CHUNKS
-- ==============================================================================
DROP TABLE IF EXISTS `ai_knowledge_chunks`;
CREATE TABLE `ai_knowledge_chunks` (
  `id` VARCHAR(36) NOT NULL,
  `document_id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `chunk_index` INT NOT NULL DEFAULT 0,
  `content` MEDIUMTEXT NOT NULL,
  `embedding` JSON DEFAULT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_ai_chunks_account` (`account_id`),
  KEY `idx_ai_chunks_document` (`document_id`),
  FULLTEXT KEY `idx_ai_chunks_fts` (`content`),
  CONSTRAINT `fk_ai_chunks_document` FOREIGN KEY (`document_id`) REFERENCES `ai_knowledge_documents` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ai_chunks_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 38. AI USAGE LOG
-- ==============================================================================
DROP TABLE IF EXISTS `ai_usage_log`;
CREATE TABLE `ai_usage_log` (
  `id` VARCHAR(36) NOT NULL,
  `account_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) DEFAULT NULL,
  `model` VARCHAR(100) NOT NULL,
  `prompt_tokens` INT NOT NULL DEFAULT 0,
  `completion_tokens` INT NOT NULL DEFAULT 0,
  `total_tokens` INT NOT NULL DEFAULT 0,
  `cost` DECIMAL(10,6) NOT NULL DEFAULT 0.000000,
  `request_type` VARCHAR(50) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_ai_usage_account` (`account_id`, `created_at`),
  CONSTRAINT `fk_ai_usage_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ai_usage_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ==============================================================================
-- 39. STORED PROCEDURES & TRIGGERS (Replaces Supabase RPCs & Triggers)
-- ==============================================================================

DELIMITER $$

-- Trigger: Update conversation's last message on new message insert
DROP TRIGGER IF EXISTS `trg_after_message_insert`$$
CREATE TRIGGER `trg_after_message_insert`
AFTER INSERT ON `messages`
FOR EACH ROW
BEGIN
  UPDATE `conversations`
  SET
    `last_message_text` = COALESCE(NEW.`content_text`, CONCAT('[', NEW.`content_type`, ']')),
    `last_message_at` = NEW.`created_at`,
    `unread_count` = CASE WHEN NEW.`sender_type` = 'customer' THEN `unread_count` + 1 ELSE `unread_count` END,
    `updated_at` = NEW.`created_at`
  WHERE `id` = NEW.`conversation_id`;
END$$

-- Trigger: Broadcast Recipient Status Counter Updates
DROP TRIGGER IF EXISTS `trg_after_recipient_status_update`$$
CREATE TRIGGER `trg_after_recipient_status_update`
AFTER UPDATE ON `broadcast_recipients`
FOR EACH ROW
BEGIN
  IF OLD.`status` <> NEW.`status` THEN
    UPDATE `broadcasts`
    SET
      `sent_count` = (SELECT COUNT(*) FROM `broadcast_recipients` WHERE `broadcast_id` = NEW.`broadcast_id` AND `status` = 'sent'),
      `delivered_count` = (SELECT COUNT(*) FROM `broadcast_recipients` WHERE `broadcast_id` = NEW.`broadcast_id` AND `status` = 'delivered'),
      `read_count` = (SELECT COUNT(*) FROM `broadcast_recipients` WHERE `broadcast_id` = NEW.`broadcast_id` AND `status` = 'read'),
      `replied_count` = (SELECT COUNT(*) FROM `broadcast_recipients` WHERE `broadcast_id` = NEW.`broadcast_id` AND `status` = 'replied'),
      `failed_count` = (SELECT COUNT(*) FROM `broadcast_recipients` WHERE `broadcast_id` = NEW.`broadcast_id` AND `status` = 'failed')
    WHERE `id` = NEW.`broadcast_id`;
  END IF;
END$$

-- Procedure: Increment Automation Execution Counter
DROP PROCEDURE IF EXISTS `increment_automation_counter`$$
CREATE PROCEDURE `increment_automation_counter`(
  IN p_automation_id VARCHAR(36)
)
BEGIN
  UPDATE `automations`
  SET
    `execution_count` = `execution_count` + 1,
    `last_executed_at` = CURRENT_TIMESTAMP(3)
  WHERE `id` = p_automation_id;
END$$

-- Procedure: Increment Flow Execution Counter
DROP PROCEDURE IF EXISTS `increment_flow_counter`$$
CREATE PROCEDURE `increment_flow_counter`(
  IN p_flow_id VARCHAR(36)
)
BEGIN
  UPDATE `flows`
  SET
    `execution_count` = `execution_count` + 1,
    `last_executed_at` = CURRENT_TIMESTAMP(3)
  WHERE `id` = p_flow_id;
END$$

-- Procedure: Filter Contacts by Tags (AND / OR logic)
DROP PROCEDURE IF EXISTS `filter_contacts_by_tags`$$
CREATE PROCEDURE `filter_contacts_by_tags`(
  IN p_account_id VARCHAR(36),
  IN p_tag_ids JSON,
  IN p_match_all BOOLEAN
)
BEGIN
  IF p_match_all = TRUE THEN
    -- Match ALL tags (intersection)
    SELECT c.*
    FROM `contacts` c
    WHERE c.`account_id` = p_account_id
      AND (
        SELECT COUNT(DISTINCT ct.`tag_id`)
        FROM `contact_tags` ct
        WHERE ct.`contact_id` = c.`id`
          AND JSON_CONTAINS(p_tag_ids, JSON_QUOTE(ct.`tag_id`))
      ) = JSON_LENGTH(p_tag_ids);
  ELSE
    -- Match ANY tag (union)
    SELECT DISTINCT c.*
    FROM `contacts` c
    INNER JOIN `contact_tags` ct ON ct.`contact_id` = c.`id`
    WHERE c.`account_id` = p_account_id
      AND JSON_CONTAINS(p_tag_ids, JSON_QUOTE(ct.`tag_id`));
  END IF;
END$$

-- Procedure: Claim Account Invitation
DROP PROCEDURE IF EXISTS `claim_account_invitation`$$
CREATE PROCEDURE `claim_account_invitation`(
  IN p_token_hash VARCHAR(255),
  IN p_user_id VARCHAR(36)
)
BEGIN
  DECLARE v_invite_id VARCHAR(36);
  DECLARE v_account_id VARCHAR(36);
  DECLARE v_role VARCHAR(20);
  DECLARE v_expires_at DATETIME(3);
  DECLARE v_accepted_at DATETIME(3);

  SELECT `id`, `account_id`, `role`, `expires_at`, `accepted_at`
  INTO v_invite_id, v_account_id, v_role, v_expires_at, v_accepted_at
  FROM `account_invitations`
  WHERE `token_hash` = p_token_hash;

  IF v_invite_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid invitation token';
  ELSEIF v_accepted_at IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invitation has already been accepted';
  ELSEIF v_expires_at < CURRENT_TIMESTAMP(3) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invitation has expired';
  ELSE
    -- Update Invitation
    UPDATE `account_invitations`
    SET `accepted_at` = CURRENT_TIMESTAMP(3),
        `accepted_by_user_id` = p_user_id
    WHERE `id` = v_invite_id;

    -- Update User Profile Membership
    UPDATE `profiles`
    SET `account_id` = v_account_id,
        `account_role` = v_role
    WHERE `user_id` = p_user_id;
  END IF;
END$$

DELIMITER ;

-- ==============================================================================
-- 40. INITIAL SEED DATA (Default Admin, Account, Pipelines, Stages)
-- ==============================================================================

-- Password for default admin is: password123 (bcrypt hash: $2b$10$qcpD0RnQeB4QLEiCq8koiurOmsnc2JhzUPNAnOBodblYL6D1iO9Bm)
INSERT INTO `users` (`id`, `email`, `password_hash`, `email_confirmed_at`, `created_at`)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'admin@wacrm.local',
  '$2b$10$qcpD0RnQeB4QLEiCq8koiurOmsnc2JhzUPNAnOBodblYL6D1iO9Bm',
  CURRENT_TIMESTAMP(3),
  CURRENT_TIMESTAMP(3)
) ON DUPLICATE KEY UPDATE `email` = VALUES(`email`);

INSERT INTO `accounts` (`id`, `name`, `owner_user_id`, `default_currency`, `created_at`)
VALUES (
  '10000000-0000-0000-0000-000000000001',
  'Primary Organization',
  '00000000-0000-0000-0000-000000000001',
  'USD',
  CURRENT_TIMESTAMP(3)
) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

INSERT INTO `profiles` (`id`, `user_id`, `account_id`, `account_role`, `full_name`, `email`, `role`, `created_at`)
VALUES (
  '20000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'owner',
  'Admin User',
  'admin@wacrm.local',
  'admin',
  CURRENT_TIMESTAMP(3)
) ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- Default Sales Pipeline
INSERT INTO `pipelines` (`id`, `user_id`, `account_id`, `name`, `created_at`)
VALUES (
  '30000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'Standard Sales Pipeline',
  CURRENT_TIMESTAMP(3)
) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Default Pipeline Stages
INSERT INTO `pipeline_stages` (`id`, `pipeline_id`, `name`, `position`, `color`, `created_at`)
VALUES
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Lead / Inbound', 0, '#3b82f6', CURRENT_TIMESTAMP(3)),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'Contacted', 1, '#8b5cf6', CURRENT_TIMESTAMP(3)),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', 'Proposal Sent', 2, '#eab308', CURRENT_TIMESTAMP(3)),
  ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001', 'Negotiation', 3, '#f97316', CURRENT_TIMESTAMP(3)),
  ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000001', 'Won', 4, '#22c55e', CURRENT_TIMESTAMP(3)),
  ('40000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000001', 'Lost', 5, '#ef4444', CURRENT_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Default Tags
INSERT INTO `tags` (`id`, `user_id`, `account_id`, `name`, `color`, `created_at`)
VALUES
  ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'VIP', '#e11d48', CURRENT_TIMESTAMP(3)),
  ('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'High Priority', '#f59e0b', CURRENT_TIMESTAMP(3)),
  ('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Customer', '#10b981', CURRENT_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);
