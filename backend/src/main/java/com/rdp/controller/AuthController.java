package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService auth;
    public AuthController(AuthService auth) { this.auth = auth; }
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.register(request));
    }
    @PostMapping("/login") public AuthResponse login(@Valid @RequestBody LoginRequest request) { return auth.login(request); }
    @GetMapping("/me") public UserView me(Authentication authentication) { return auth.me(authentication.getName()); }
    @PutMapping("/security-questions")
    public Map<String, String> securityQuestions(Authentication authentication,
                                                  @Valid @RequestBody SecurityAnswersInput input) {
        auth.setSecurityAnswers(authentication.getName(), input);
        return Map.of("message", "Password recovery questions saved.");
    }
    @PostMapping("/password/reset")
    public Map<String, String> resetPassword(@Valid @RequestBody PasswordRecoveryInput input,
                                             HttpServletRequest request) {
        auth.resetPassword(input, request.getRemoteAddr());
        return Map.of("message", "Password updated. Sign in with your new password.");
    }
    @PostMapping("/logout") public Map<String, String> logout() { return Map.of("message", "Signed out. Remove the access token from this device."); }
}
