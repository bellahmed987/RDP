package com.rdp.repository;

import com.rdp.entity.AccountStatus;
import com.rdp.entity.AppUser;
import com.rdp.entity.Role;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AppUserRepository extends JpaRepository<AppUser, Long> {
    Optional<AppUser> findByEmailIgnoreCase(String email);
    Optional<AppUser> findByGoogleSubject(String googleSubject);
    boolean existsByEmailIgnoreCase(String email);
    long countByRole(Role role);
    long countByStatus(AccountStatus status);
    Page<AppUser> findByNameContainingIgnoreCaseOrEmailContainingIgnoreCase(String name, String email, Pageable pageable);
    List<AppUser> findTop20ByOrderByCreatedAtDesc();
}
