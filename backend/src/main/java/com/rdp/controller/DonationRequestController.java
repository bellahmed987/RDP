package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.RequestStatus;
import com.rdp.service.RequestService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api")
public class DonationRequestController {
    private final RequestService requests;
    public DonationRequestController(RequestService requests) { this.requests = requests; }
    @PostMapping("/donations/{donationId}/requests") @PreAuthorize("hasRole('RECIPIENT')")
    public ResponseEntity<RequestView> create(Authentication auth, @PathVariable Long donationId, @Valid @RequestBody RequestInput input) {
        return ResponseEntity.status(HttpStatus.CREATED).body(requests.create(auth.getName(), donationId, input));
    }
    @GetMapping("/requests/mine") @PreAuthorize("hasRole('RECIPIENT')")
    public List<RequestView> mine(Authentication auth) { return requests.mine(auth.getName()); }
    @GetMapping("/requests/incoming") @PreAuthorize("hasRole('DONOR')")
    public List<RequestView> incoming(Authentication auth) { return requests.incoming(auth.getName()); }
    @GetMapping("/requests/{id}") public RequestView get(Authentication auth, @PathVariable Long id) {
        return requests.get(auth.getName(), id);
    }
    @PatchMapping("/requests/{id}/decision") @PreAuthorize("hasRole('DONOR')")
    public RequestView decide(Authentication auth, @PathVariable Long id, @Valid @RequestBody DecisionInput input) {
        return requests.decide(auth.getName(), id, input.status());
    }
    @PatchMapping("/requests/{id}/cancel") @PreAuthorize("hasRole('RECIPIENT')")
    public RequestView cancel(Authentication auth, @PathVariable Long id) { return requests.cancel(auth.getName(), id); }
    @PatchMapping("/requests/{id}/complete") @PreAuthorize("hasRole('DONOR')")
    public RequestView complete(Authentication auth, @PathVariable Long id) { return requests.complete(auth.getName(), id); }
}
