package com.rdp.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import java.time.Instant;

@Entity
@Table(name = "user_blocks", uniqueConstraints = @UniqueConstraint(name = "uk_user_block_pair", columnNames = {"blocker_id", "blocked_id"}))
@Getter @Setter @NoArgsConstructor
public class UserBlock {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "blocker_id", nullable = false)
    private AppUser blocker;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "blocked_id", nullable = false)
    private AppUser blocked;
    @CreationTimestamp @Column(nullable = false, updatable = false)
    private Instant createdAt;
}
