package com.rdp.service;

import com.rdp.dto.ApiDtos.NotificationView;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.AppNotificationRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class NotificationService {
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
        notifications.save(notification);
        push.send(recipient, notification);
    }
    @Transactional(readOnly = true)
    public List<NotificationView> mine(Long userId) {
        return notifications.findTop100ByUserIdOrderByCreatedAtDesc(userId).stream().map(mapper::notification).toList();
    }
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
