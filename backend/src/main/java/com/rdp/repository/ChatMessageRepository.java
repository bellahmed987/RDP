package com.rdp.repository;

import com.rdp.entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findTop100ByConversationIdOrderByCreatedAtAsc(Long conversationId);
    Optional<ChatMessage> findTop1ByConversationIdOrderByCreatedAtDesc(Long conversationId);
    long countByConversationIdAndSenderIdNotAndReadAtIsNull(Long conversationId, Long senderId);
}
