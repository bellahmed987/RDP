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
    private final RequestService requests;
    public AdminController(AdminService admin, DonationService donations, RequestService requests) { this.admin = admin; this.donations = donations; this.requests = requests; }
    @GetMapping("/stats") public AdminStats stats() { return admin.stats(); }
    @GetMapping("/users") public PageView<UserView> users(@RequestParam(required = false) String q,
            @RequestParam(required = false) com.rdp.entity.Role role,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return admin.users(q, role, page, size);
    }
    @PatchMapping("/users/{id}/status") public UserView status(@PathVariable Long id, @Valid @RequestBody UserStatusInput input) {
        return admin.status(id, input.status());
    }
    @GetMapping("/donations") public List<DonationView> donations() { return admin.donations(); }
    @GetMapping("/donations/{id}") public DonationView donation(@PathVariable Long id) { return admin.donation(id); }
    @DeleteMapping("/donations/{id}") public void removeDonation(@PathVariable Long id) { donations.adminRemove(id); }
    @GetMapping("/requests") public List<RequestView> requests() { return requests.allForAdmin(); }
    @PatchMapping("/requests/{id}/decision") public RequestView decideRequest(@PathVariable Long id, @Valid @RequestBody DecisionInput input,
                                                                                 org.springframework.security.core.Authentication auth) {
        return requests.decide(auth.getName(), id, input.status());
    }
    @PatchMapping("/requests/{id}/complete") public RequestView completeRequest(@PathVariable Long id,
                                                                                   org.springframework.security.core.Authentication auth) {
        return requests.complete(auth.getName(), id);
    }
}
