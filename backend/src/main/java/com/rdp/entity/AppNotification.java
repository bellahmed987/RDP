package com.rdp.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import java.time.Instant;

@Entity
@Table(name = "notifications", indexes = @Index(name = "idx_notifications_user_created", columnList = "user_id,createdAt"))
@Getter @Setter @NoArgsConstructor
public class AppNotification {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 24)
    private NotificationType type;
    @Column(nullable = false, length = 180)
    private String title;
    @Column(nullable = false, length = 600)
    private String body;
    private Long referenceId;
    @Column(name = "is_read", nullable = false)
    private boolean read;
    @CreationTimestamp @Column(nullable = false, updatable = false)
    private Instant createdAt;
}
