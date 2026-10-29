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
    Optional<AppUser> findByUsernameIgnoreCase(String username);
    boolean existsByUsernameIgnoreCase(String username);
    boolean existsByEmailIgnoreCase(String email);
    long countByRole(Role role);
    long countByStatus(AccountStatus status);
    Page<AppUser> findByNameContainingIgnoreCaseOrEmailContainingIgnoreCase(String name, String email, Pageable pageable);
    Page<AppUser> findByNameContainingIgnoreCaseOrEmailContainingIgnoreCaseOrUsernameContainingIgnoreCase(String name, String email, String username, Pageable pageable);
    Page<AppUser> findByRole(Role role, Pageable pageable);
    Page<AppUser> findByRoleAndNameContainingIgnoreCaseOrRoleAndEmailContainingIgnoreCase(Role nameRole, String name,
                                                                                         Role emailRole, String email, Pageable pageable);
    Page<AppUser> findByRoleAndNameContainingIgnoreCaseOrRoleAndEmailContainingIgnoreCaseOrRoleAndUsernameContainingIgnoreCase(
            Role nameRole, String name, Role emailRole, String email, Role usernameRole, String username, Pageable pageable);
    List<AppUser> findTop20ByOrderByCreatedAtDesc();
}
