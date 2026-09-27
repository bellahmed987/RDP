package com.rdp.repository;

import com.rdp.entity.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface ConversationRepository extends JpaRepository<Conversation, Long> {
    Optional<Conversation> findByRequestId(Long requestId);
    List<Conversation> findByDonorIdOrRecipientIdOrderByCreatedAtDesc(Long donorId, Long recipientId);
}
