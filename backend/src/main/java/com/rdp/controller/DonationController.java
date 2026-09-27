package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.DonationCategory;
import com.rdp.service.*;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/donations")
public class DonationController {
    private final DonationService donations;
    private final ImageStorageService images;
    public DonationController(DonationService donations, ImageStorageService images) { this.donations = donations; this.images = images; }

    @GetMapping
    public PageView<DonationView> discover(Authentication auth, @RequestParam(required = false) String q,
            @RequestParam(required = false) DonationCategory category, @RequestParam(required = false) String city,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return donations.discover(auth == null ? null : auth.getName(), q, category, city, page, size);
    }
    @GetMapping("/nearby")
    public PageView<DonationView> nearby(Authentication auth, @RequestParam double latitude, @RequestParam double longitude,
            @RequestParam(defaultValue = "5") double radiusKm, @RequestParam(required = false) DonationCategory category,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return donations.nearby(auth == null ? null : auth.getName(), latitude, longitude, radiusKm, category, page, size);
    }
    @GetMapping("/mine") @PreAuthorize("hasRole('DONOR')")
    public java.util.List<DonationView> mine(Authentication auth) { return donations.mine(auth.getName()); }
    @GetMapping("/{id}") public DonationView get(Authentication auth, @PathVariable Long id) {
        return donations.get(auth == null ? null : auth.getName(), id);
    }
    @PostMapping @PreAuthorize("hasRole('DONOR')")
    public ResponseEntity<DonationView> create(Authentication auth, @Valid @RequestBody DonationInput input) {
        return ResponseEntity.status(HttpStatus.CREATED).body(donations.create(auth.getName(), input));
    }
    @PutMapping("/{id}") @PreAuthorize("hasRole('DONOR')")
    public DonationView update(Authentication auth, @PathVariable Long id, @Valid @RequestBody DonationInput input) {
        return donations.update(auth.getName(), id, input);
    }
    @DeleteMapping("/{id}") @PreAuthorize("hasRole('DONOR')")
    public ResponseEntity<Void> cancel(Authentication auth, @PathVariable Long id) {
        donations.cancel(auth.getName(), id);
        return ResponseEntity.noContent().build();
    }
    @PostMapping(value = "/{id}/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('DONOR')")
    public DonationView image(Authentication auth, @PathVariable Long id, @RequestPart("file") MultipartFile file) {
        return donations.addImage(auth.getName(), id, images.store(file));
    }
}
