package com.rdp.controller;

import com.rdp.dto.ApiDtos.NotificationView;
import com.rdp.service.*;
import jakarta.validation.constraints.NotBlank;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
@Validated
public class NotificationController {
    private final CurrentUserService current;
    private final NotificationService notifications;
    public NotificationController(CurrentUserService current, NotificationService notifications) {
        this.current = current; this.notifications = notifications;
    }
    @GetMapping public List<NotificationView> mine(Authentication auth) {
        return notifications.mine(current.require(auth.getName()).getId());
    }
    @PatchMapping("/{id}/read") public NotificationView read(Authentication auth, @PathVariable Long id) {
        return notifications.markRead(current.require(auth.getName()).getId(), id);
    }
    @PutMapping("/device-token") public Map<String, String> token(Authentication auth, @RequestBody TokenInput input) {
        notifications.saveDeviceToken(current.require(auth.getName()), input.token());
        return Map.of("message", "Device token saved.");
    }
    public record TokenInput(@NotBlank String token) {}
}
