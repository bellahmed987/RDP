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

@Service
public class AuthService {
    private final AppUserRepository users;
    private final PasswordEncoder passwords;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwt;
    private final ApiMapper mapper;
    public AuthService(AppUserRepository users, PasswordEncoder passwords, AuthenticationManager authenticationManager,
                       JwtService jwt, ApiMapper mapper) {
        this.users = users; this.passwords = passwords; this.authenticationManager = authenticationManager;
        this.jwt = jwt; this.mapper = mapper;
    }
    @Transactional
    public AuthResponse register(RegisterRequest input) {
        if (input.role() == Role.ADMIN) throw ApiException.forbidden("Admin accounts are created only through the secure development bootstrap.");
        String email = input.email().trim().toLowerCase();
        if (users.existsByEmailIgnoreCase(email)) throw ApiException.conflict("An account with this email already exists.");
        AppUser user = new AppUser();
        user.setName(input.name().trim()); user.setEmail(email); user.setPasswordHash(passwords.encode(input.password()));
        user.setPhone(input.phone()); user.setCity(input.city()); user.setRole(input.role()); user.setStatus(AccountStatus.ACTIVE);
        user = users.save(user);
        return new AuthResponse(jwt.create(user), "Bearer", mapper.user(user));
    }
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest input) {
        try {
            authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(input.email().trim().toLowerCase(), input.password()));
        } catch (AuthenticationException ex) {
            throw new ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "Email or password is incorrect, or the account is inactive.");
        }
        AppUser user = users.findByEmailIgnoreCase(input.email().trim()).orElseThrow(() ->
                new ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "Email or password is incorrect."));
        return new AuthResponse(jwt.create(user), "Bearer", mapper.user(user));
    }
    @Transactional(readOnly = true)
    public UserView me(String email) {
        return mapper.user(users.findByEmailIgnoreCase(email).orElseThrow(() -> ApiException.notFound("Account not found.")));
    }
}
