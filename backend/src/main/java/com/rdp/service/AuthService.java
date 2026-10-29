package com.rdp.service;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.AppUserRepository;
import com.rdp.security.JwtService;
import org.springframework.security.authentication.*;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import java.text.Normalizer;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

@Service
public class AuthService {
    private final AppUserRepository users;
    private final PasswordEncoder passwords;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwt;
    private final ApiMapper mapper;
    private final ConcurrentMap<String, RecoveryWindow> recoveryWindows = new ConcurrentHashMap<>();
    public AuthService(AppUserRepository users, PasswordEncoder passwords, AuthenticationManager authenticationManager,
                       JwtService jwt, ApiMapper mapper) {
        this.users = users; this.passwords = passwords; this.authenticationManager = authenticationManager;
        this.jwt = jwt; this.mapper = mapper;
    }
    @Transactional
    public AuthResponse register(RegisterRequest input) {
        if (input.role() == Role.ADMIN) throw ApiException.forbidden("Admin accounts are created only through the secure development bootstrap.");
        String username = input.username().trim().toLowerCase(Locale.ROOT);
        if (users.existsByUsernameIgnoreCase(username)) throw ApiException.conflict("That username is already taken.");
        String email = username.toLowerCase(Locale.ROOT) + "@accounts.sharekind.invalid";
        AppUser user = new AppUser();
        user.setName(input.name().trim()); user.setUsername(username); user.setEmail(email); user.setPasswordHash(passwords.encode(input.password()));
        user.setPhone(input.phone()); user.setCity(input.city()); user.setRole(input.role()); user.setStatus(AccountStatus.ACTIVE);
        String[] answers = {input.answer1(), input.answer2(), input.answer3(), input.answer4()};
        boolean anyAnswer = java.util.Arrays.stream(answers).anyMatch(a -> a != null && !a.isBlank());
        if (anyAnswer && java.util.Arrays.stream(answers).anyMatch(a -> a == null || a.isBlank()))
            throw ApiException.badRequest("Please answer all four recovery questions, or leave all four blank.");
        if (anyAnswer) saveSecurityAnswers(user, answers);
        user = users.save(user);
        return new AuthResponse(null, "Bearer", mapper.user(user));
    }
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest input) {
        String identifier = input.username().trim();
        AppUser user = users.findByUsernameIgnoreCase(identifier).orElseGet(() ->
                users.findByEmailIgnoreCase(identifier).orElseThrow(() ->
                        new ApiException(HttpStatus.UNAUTHORIZED, "Username or password is incorrect.")));
        try {
            authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(user.getEmail(), input.password()));
        } catch (AuthenticationException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Username or password is incorrect, or the account is inactive.");
        }
        return new AuthResponse(jwt.create(user), "Bearer", mapper.user(user));
    }
    @Transactional(readOnly = true)
    public UserView me(String email) {
        return mapper.user(users.findByEmailIgnoreCase(email).orElseThrow(() -> ApiException.notFound("Account not found.")));
    }

    @Transactional
    public void setSecurityAnswers(String email, SecurityAnswersInput input) {
        AppUser user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> ApiException.notFound("Account not found."));
        if (!passwords.matches(input.currentPassword(), user.getPasswordHash()))
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Current password is incorrect.");
        saveSecurityAnswers(user, new String[]{input.answer1(), input.answer2(), input.answer3(), input.answer4()});
    }

    @Transactional
    public void resetPassword(PasswordRecoveryInput input, String remoteAddress) {
        String username = input.username().trim();
        String key = username.toLowerCase(Locale.ROOT) + "|" + (remoteAddress == null ? "unknown" : remoteAddress);
        RecoveryWindow window = recoveryWindows.computeIfAbsent(key, ignored -> new RecoveryWindow());
        synchronized (window) {
            long now = System.currentTimeMillis();
            if (now - window.startedAt > 15 * 60 * 1000L) {
                window.startedAt = now;
                window.failures = 0;
            }
            if (window.failures >= 5)
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "Too many recovery attempts. Try again in 15 minutes.");
        }

        AppUser user = users.findByUsernameIgnoreCase(username).orElseGet(() ->
                users.findByEmailIgnoreCase(username).orElse(null));
        boolean matches = user != null && user.getSecurityAnswerHash1() != null
                && user.getSecurityAnswerHash2() != null && user.getSecurityAnswerHash3() != null
                && user.getSecurityAnswerHash4() != null;
        if (matches) {
            matches &= passwords.matches(normalizeAnswer(input.answer1()), user.getSecurityAnswerHash1());
            matches &= passwords.matches(normalizeAnswer(input.answer2()), user.getSecurityAnswerHash2());
            matches &= passwords.matches(normalizeAnswer(input.answer3()), user.getSecurityAnswerHash3());
            matches &= passwords.matches(normalizeAnswer(input.answer4()), user.getSecurityAnswerHash4());
        }
        if (!matches) {
            synchronized (window) { window.failures++; }
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Username or recovery answers are incorrect, or recovery has not been set up.");
        }

        user.setPasswordHash(passwords.encode(input.newPassword()));
        recoveryWindows.remove(key, window);
    }

    private void saveSecurityAnswers(AppUser user, String[] answers) {
        user.setSecurityAnswerHash1(passwords.encode(normalizeAnswer(answers[0])));
        user.setSecurityAnswerHash2(passwords.encode(normalizeAnswer(answers[1])));
        user.setSecurityAnswerHash3(passwords.encode(normalizeAnswer(answers[2])));
        user.setSecurityAnswerHash4(passwords.encode(normalizeAnswer(answers[3])));
    }

    private String normalizeAnswer(String answer) {
        return Normalizer.normalize(answer, Normalizer.Form.NFKC)
                .trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
    }

    private static final class RecoveryWindow {
        private long startedAt = System.currentTimeMillis();
        private int failures;
    }
}
