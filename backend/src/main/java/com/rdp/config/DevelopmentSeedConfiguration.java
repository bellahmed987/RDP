package com.rdp.config;

import com.rdp.entity.AccountStatus;
import com.rdp.entity.AppUser;
import com.rdp.entity.Role;
import com.rdp.repository.AppUserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

@Configuration
public class DevelopmentSeedConfiguration implements ApplicationRunner {
    private final AppUserRepository users;
    private final PasswordEncoder encoder;
    @Value("$" + "{app.bootstrap.admin-email:}") private String adminEmail;
    @Value("$" + "{app.bootstrap.admin-password:}") private String adminPassword;
    @Value("$" + "{app.bootstrap.demo-password:}") private String demoPassword;

    public DevelopmentSeedConfiguration(AppUserRepository users, PasswordEncoder encoder) {
        this.users = users; this.encoder = encoder;
    }

    @Override @Transactional
    public void run(ApplicationArguments args) {
        if (adminEmail != null && !adminEmail.isBlank() && adminPassword != null && adminPassword.length() >= 12) {
            createIfMissing("Development Administrator", adminEmail, adminPassword, Role.ADMIN);
        }
        if (demoPassword != null && demoPassword.length() >= 12) {
            createIfMissing("Demo Donor", "donor@example.local", demoPassword, Role.DONOR);
            createIfMissing("Demo Recipient", "recipient@example.local", demoPassword, Role.RECIPIENT);
        }
    }

    private void createIfMissing(String name, String email, String password, Role role) {
        if (users.existsByEmailIgnoreCase(email)) return;
        AppUser user = new AppUser();
        user.setName(name); user.setEmail(email.toLowerCase()); user.setPasswordHash(encoder.encode(password));
        user.setRole(role); user.setStatus(AccountStatus.ACTIVE); users.save(user);
    }
}
