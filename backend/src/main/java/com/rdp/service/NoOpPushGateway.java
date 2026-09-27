package com.rdp.service;

import com.rdp.entity.*;
public class NoOpPushGateway implements PushGateway {
    @Override public void send(AppUser recipient, AppNotification notification) {
        // In-app notifications remain available when Firebase credentials are not configured.
    }
}
