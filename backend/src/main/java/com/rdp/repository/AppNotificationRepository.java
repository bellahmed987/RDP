package com.rdp.repository;

import com.rdp.entity.AppNotification;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AppNotificationRepository extends JpaRepository<AppNotification, Long> {
    List<AppNotification> findTop100ByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<AppNotification> findByIdAndUserId(Long id, Long userId);
}
