package com.rdp.controller;

import com.rdp.dto.ApiDtos.DonationView;
import com.rdp.service.FavoriteService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/favorites")
@PreAuthorize("hasRole('RECIPIENT')")
public class FavoriteController {
    private final FavoriteService favorites;
    public FavoriteController(FavoriteService favorites) { this.favorites = favorites; }
    @GetMapping public List<DonationView> mine(Authentication auth) { return favorites.mine(auth.getName()); }
    @PostMapping("/{donationId}") public ResponseEntity<Void> add(Authentication auth, @PathVariable Long donationId) {
        favorites.add(auth.getName(), donationId); return ResponseEntity.noContent().build();
    }
    @DeleteMapping("/{donationId}") public ResponseEntity<Void> remove(Authentication auth, @PathVariable Long donationId) {
        favorites.remove(auth.getName(), donationId); return ResponseEntity.noContent().build();
    }
}
