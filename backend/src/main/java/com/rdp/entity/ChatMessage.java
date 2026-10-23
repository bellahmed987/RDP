package com.rdp.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import java.time.Instant;

@Entity
@Table(name = "messages", indexes = @Index(name = "idx_messages_conversation_time", columnList = "conversation_id,createdAt"))
@Getter @Setter @NoArgsConstructor
public class ChatMessage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "sender_id", nullable = false)
    private AppUser sender;
    @Column(nullable = false, length = 4000)
    private String body;
    @Enumerated(EnumType.STRING) @Column(length = 16)
    private MessageKind kind = MessageKind.TEXT;
    @Column(length = 500)
    private String attachmentUrl;
    private Double latitude;
    private Double longitude;
    private Instant readAt;
    @CreationTimestamp @Column(nullable = false, updatable = false)
    private Instant createdAt;
}
