package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.AuthService;
import com.rdp.service.GoogleAuthService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService auth;
    private final GoogleAuthService googleAuth;
    public AuthController(AuthService auth, GoogleAuthService googleAuth) {
        this.auth = auth;
        this.googleAuth = googleAuth;
    }
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.register(request));
    }
    @PostMapping("/login") public AuthResponse login(@Valid @RequestBody LoginRequest request) { return auth.login(request); }
    @PostMapping("/google") public GoogleAuthResponse google(@Valid @RequestBody GoogleAuthRequest request) {
        return googleAuth.authenticate(request);
    }
    @GetMapping("/me") public UserView me(Authentication authentication) { return auth.me(authentication.getName()); }
    @PostMapping("/logout") public Map<String, String> logout() { return Map.of("message", "Signed out. Remove the access token from this device."); }
}
