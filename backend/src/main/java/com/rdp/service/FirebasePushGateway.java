package com.rdp.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.rdp.entity.AppNotification;
import com.rdp.entity.AppUser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FirebasePushGateway implements PushGateway {
    private static final Logger log = LoggerFactory.getLogger(FirebasePushGateway.class);
    private final FirebaseMessaging messaging;
    public FirebasePushGateway(FirebaseMessaging messaging) { this.messaging = messaging; }

    @Override public void send(AppUser recipient, AppNotification notification) {
        if (recipient.getFirebaseToken() == null || recipient.getFirebaseToken().isBlank()) return;
        try {
            messaging.send(Message.builder().setToken(recipient.getFirebaseToken())
                    .putData("notificationId", String.valueOf(notification.getId()))
                    .putData("type", notification.getType().name())
                    .setNotification(com.google.firebase.messaging.Notification.builder()
                            .setTitle(notification.getTitle()).setBody(notification.getBody()).build()).build());
        } catch (Exception ex) {
            log.warn("FCM delivery failed for user {}: {}", recipient.getId(), ex.getMessage());
        }
    }
}
