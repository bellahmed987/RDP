package com.rdp.service;

import com.rdp.entity.AppUser;
import com.rdp.exception.ApiException;
import com.rdp.repository.AppUserRepository;
import org.springframework.stereotype.Service;

@Service
public class CurrentUserService {
    private final AppUserRepository users;
    public CurrentUserService(AppUserRepository users) { this.users = users; }
    public AppUser require(String email) {
        return users.findByEmailIgnoreCase(email).orElseThrow(() -> ApiException.notFound("Account not found."));
    }
}
