package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.AccountStatus;
import com.rdp.service.*;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {
    private final AdminService admin;
    private final DonationService donations;
    public AdminController(AdminService admin, DonationService donations) { this.admin = admin; this.donations = donations; }
    @GetMapping("/stats") public AdminStats stats() { return admin.stats(); }
    @GetMapping("/users") public PageView<UserView> users(@RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return admin.users(q, page, size);
    }
    @PatchMapping("/users/{id}/status") public UserView status(@PathVariable Long id, @Valid @RequestBody UserStatusInput input) {
        return admin.status(id, input.status());
    }
    @GetMapping("/donations") public List<DonationView> donations() { return admin.donations(); }
    @GetMapping("/donations/{id}") public DonationView donation(@PathVariable Long id) { return admin.donation(id); }
    @DeleteMapping("/donations/{id}") public void removeDonation(@PathVariable Long id) { donations.adminRemove(id); }
}
