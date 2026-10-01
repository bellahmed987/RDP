package com.rdp.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.rdp.dto.ApiDtos.AuthResponse;
import com.rdp.dto.ApiDtos.GoogleAuthRequest;
import com.rdp.dto.ApiDtos.GoogleAuthResponse;
import com.rdp.entity.AccountStatus;
import com.rdp.entity.AppUser;
import com.rdp.entity.Role;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.AppUserRepository;
import com.rdp.security.JwtService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.List;
import java.util.UUID;

@Service
public class GoogleAuthService {
    private final AppUserRepository users;
    private final PasswordEncoder passwords;
    private final JwtService jwt;
    private final ApiMapper mapper;
    private final String clientId;
    private final GoogleIdTokenVerifier verifier;

    public GoogleAuthService(AppUserRepository users, PasswordEncoder passwords, JwtService jwt,
                             ApiMapper mapper, @Value("${app.google.client-id:}") String clientId) {
        this.users = users;
        this.passwords = passwords;
        this.jwt = jwt;
        this.mapper = mapper;
        this.clientId = clientId == null ? "" : clientId.trim();
        this.verifier = this.clientId.isBlank() ? null : new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(List.of(this.clientId)).build();
    }

    @Transactional
    public GoogleAuthResponse authenticate(GoogleAuthRequest request) {
        if (clientId.isBlank()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Google sign-in is not configured. Add GOOGLE_CLIENT_ID to .env.local and restart the backend.");
        }

        final GoogleIdToken token;
        try {
            token = verifier.verify(request.idToken());
        } catch (IOException | GeneralSecurityException ex) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Google could not be reached to verify your sign-in. Please try again.");
        }
        if (token == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "The Google sign-in token is invalid or expired.");
        }

        GoogleIdToken.Payload claims = token.getPayload();
        String subject = claims.getSubject();
        String email = claims.getEmail();
        if (subject == null || subject.isBlank() || email == null || email.isBlank()
                || !Boolean.TRUE.equals(claims.getEmailVerified())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "Google must provide a verified email address for sign-in.");
        }
        email = email.trim().toLowerCase();

        AppUser user = users.findByGoogleSubject(subject).orElse(null);
        if (user == null) {
            user = users.findByEmailIgnoreCase(email).orElse(null);
            if (user != null) {
                if (user.getRole() == Role.ADMIN) {
                    throw new ApiException(HttpStatus.FORBIDDEN,
                            "Administrator accounts must use administrator sign-in.");
                }
                if (user.getGoogleSubject() != null && !user.getGoogleSubject().equals(subject)) {
                    throw ApiException.conflict("This email is already linked to another Google account.");
                }
                user.setGoogleSubject(subject);
            } else {
                if (request.role() == null) {
                    return new GoogleAuthResponse(true, null);
                }
                if (request.role() == Role.ADMIN) {
                    throw ApiException.forbidden("Google sign-in cannot create administrator accounts.");
                }
                user = new AppUser();
                user.setName(displayName(claims.get("name"), email));
                user.setEmail(email);
                user.setGoogleSubject(subject);
                user.setPasswordHash(passwords.encode(UUID.randomUUID().toString()));
                user.setProfileImageUrl(verifiedPicture(claims.get("picture")));
                user.setRole(request.role());
                user.setStatus(AccountStatus.ACTIVE);
            }
        }

        if (user.getRole() == Role.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Administrator accounts must use administrator sign-in.");
        }
        if (user.getStatus() != AccountStatus.ACTIVE) {
            throw ApiException.forbidden("This account is not active.");
        }

        user = users.save(user);
        AuthResponse auth = new AuthResponse(jwt.create(user), "Bearer", mapper.user(user));
        return new GoogleAuthResponse(false, auth);
    }

    private String displayName(Object claim, String email) {
        String value = claim == null ? "" : claim.toString().trim();
        int at = email.indexOf('@');
        if (value.isBlank()) value = at > 0 ? email.substring(0, at) : "Google user";
        return value.length() <= 120 ? value : value.substring(0, 120);
    }

    private String verifiedPicture(Object claim) {
        if (claim == null) return null;
        String value = claim.toString();
        return value.length() <= 500 ? value : null;
    }
}
