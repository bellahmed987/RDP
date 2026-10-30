package com.rdp.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "admin_role_changes", indexes = @Index(name = "idx_admin_role_changes_created", columnList = "created_at"))
@Getter @Setter @NoArgsConstructor
public class AdminRoleChange {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "actor_id", nullable = false)
    private AppUser actor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "target_id", nullable = false)
    private AppUser target;

    @Enumerated(EnumType.STRING)
    @Column(name = "previous_role", nullable = false, length = 16)
    private Role previousRole;

    @Enumerated(EnumType.STRING)
    @Column(name = "new_role", nullable = false, length = 16)
    private Role newRole;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
