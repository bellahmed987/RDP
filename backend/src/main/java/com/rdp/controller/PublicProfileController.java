package com.rdp.controller;

import com.rdp.dto.ApiDtos.PublicProfileView;
import com.rdp.service.DonorProfileService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/profiles")
public class PublicProfileController {
    private final DonorProfileService profiles;

    public PublicProfileController(DonorProfileService profiles) { this.profiles = profiles; }

    @GetMapping("/{id}")
    public PublicProfileView get(@PathVariable Long id) { return profiles.getPublic(id); }
}
