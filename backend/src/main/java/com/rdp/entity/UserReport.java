package com.rdp.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import java.time.Instant;

@Entity
@Table(name = "reports", indexes = @Index(name = "idx_reports_status_created", columnList = "status,createdAt"))
@Getter @Setter @NoArgsConstructor
public class UserReport {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "reporter_id", nullable = false)
    private AppUser reporter;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "reported_user_id")
    private AppUser reportedUser;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "donation_id")
    private Donation donation;
    @Column(nullable = false, length = 100)
    private String reason;
    @Column(length = 2000)
    private String details;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 16)
    private ReportStatus status = ReportStatus.OPEN;
    @CreationTimestamp @Column(nullable = false, updatable = false)
    private Instant createdAt;
}
