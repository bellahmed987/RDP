package com.rdp.controller;

import com.rdp.service.UserBlockService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/users/{userId}/block")
public class UserBlockController {
    private final UserBlockService blocks;
    public UserBlockController(UserBlockService blocks) { this.blocks = blocks; }
    @GetMapping public Map<String, Boolean> status(Authentication auth, @PathVariable Long userId) {
        return blocks.status(auth.getName(), userId);
    }
    @PutMapping public Map<String, Boolean> block(Authentication auth, @PathVariable Long userId) {
        return blocks.block(auth.getName(), userId);
    }
    @DeleteMapping public Map<String, Boolean> unblock(Authentication auth, @PathVariable Long userId) {
        return blocks.unblock(auth.getName(), userId);
    }
}
