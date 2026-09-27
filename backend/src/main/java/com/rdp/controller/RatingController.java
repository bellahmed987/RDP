package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.RatingService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api")
public class RatingController {
    private final RatingService ratings;
    public RatingController(RatingService ratings) { this.ratings = ratings; }
    @PostMapping("/requests/{requestId}/rating") @PreAuthorize("hasRole('RECIPIENT')")
    public ResponseEntity<RatingView> create(Authentication auth, @PathVariable Long requestId, @Valid @RequestBody RatingInput input) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ratings.create(auth.getName(), requestId, input));
    }
    @GetMapping("/donors/{donorId}/ratings") public List<RatingView> donorRatings(@PathVariable Long donorId) {
        return ratings.forDonor(donorId);
    }
}
