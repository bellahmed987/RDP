package com.rdp.service;

import com.rdp.dto.ApiDtos.NotificationView;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.AppNotificationRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.util.List;

@Service
public class NotificationService {
    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);
    private final AppNotificationRepository notifications;
    private final ApiMapper mapper;
    private final PushGateway push;
    public NotificationService(AppNotificationRepository notifications, ApiMapper mapper, PushGateway push) {
        this.notifications = notifications; this.mapper = mapper; this.push = push;
    }
    @Transactional
    public void create(AppUser recipient, NotificationType type, String title, String body, Long referenceId) {
        AppNotification notification = new AppNotification();
        notification.setUser(recipient); notification.setType(type); notification.setTitle(title);
        notification.setBody(body); notification.setReferenceId(referenceId);
        AppNotification saved = notifications.saveAndFlush(notification);
        Runnable deliverPush = () -> {
            try {
                push.send(recipient, saved);
            } catch (RuntimeException ex) {
                log.warn("Push delivery failed for user {} after saving notification {}: {}",
                        recipient.getId(), saved.getId(), ex.getMessage());
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCommit() { deliverPush.run(); }
            });
        } else {
            deliverPush.run();
        }
    }
    @Transactional(readOnly = true)
    public List<NotificationView> mine(Long userId) {
        return notifications.findTop100ByUserIdOrderByCreatedAtDesc(userId).stream().map(mapper::notification).toList();
    }
    @Transactional(readOnly = true)
    public long unreadCount(Long userId) { return notifications.countByUserIdAndReadFalse(userId); }
    @Transactional
    public NotificationView markRead(Long userId, Long id) {
        AppNotification notification = notifications.findByIdAndUserId(id, userId)
                .orElseThrow(() -> ApiException.notFound("Notification not found."));
        notification.setRead(true);
        return mapper.notification(notification);
    }
    @Transactional
    public void saveDeviceToken(AppUser user, String token) {
        if (token == null || token.isBlank() || token.length() > 500) throw ApiException.badRequest("A valid device token is required.");
        user.setFirebaseToken(token);
    }
}
