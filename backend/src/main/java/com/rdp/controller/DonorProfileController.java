package com.rdp.controller;

import com.rdp.dto.ApiDtos.DonorProfileView;
import com.rdp.service.DonorProfileService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/donors")
public class DonorProfileController {
    private final DonorProfileService profiles;

    public DonorProfileController(DonorProfileService profiles) {
        this.profiles = profiles;
    }

    @GetMapping("/{id}/profile")
    public DonorProfileView get(Authentication auth, @PathVariable Long id) {
        return profiles.get(id);
    }
}
