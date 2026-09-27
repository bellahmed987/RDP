package com.rdp.service;

import com.rdp.entity.AppUser;
import com.rdp.entity.AppNotification;

public interface PushGateway {
    void send(AppUser recipient, AppNotification notification);
}
