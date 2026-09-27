package com.rdp.security;

import com.rdp.entity.AppUser;
import com.rdp.repository.AppUserRepository;
import org.springframework.security.core.userdetails.*;
import org.springframework.stereotype.Service;

@Service
public class RdpUserDetailsService implements UserDetailsService {
    private final AppUserRepository users;
    public RdpUserDetailsService(AppUserRepository users) { this.users = users; }
    @Override public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        AppUser user = users.findByEmailIgnoreCase(email).orElseThrow(() -> new UsernameNotFoundException("Account not found"));
        return User.withUsername(user.getEmail()).password(user.getPasswordHash()).roles(user.getRole().name())
                .disabled(user.getStatus() != com.rdp.entity.AccountStatus.ACTIVE).build();
    }
}
