package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.ProfileService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/profile")
public class ProfileController {
    private final ProfileService profiles;
    public ProfileController(ProfileService profiles) { this.profiles = profiles; }
    @GetMapping public UserView get(Authentication auth) { return profiles.get(auth.getName()); }
    @PutMapping public UserView update(Authentication auth, @Valid @RequestBody ProfileUpdate input) {
        return profiles.update(auth.getName(), input);
    }
}
