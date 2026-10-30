package com.rdp.repository;

import com.rdp.entity.AdminRoleChange;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AdminRoleChangeRepository extends JpaRepository<AdminRoleChange, Long> {
    List<AdminRoleChange> findTop10ByOrderByCreatedAtDesc();
}
