package com.rdp.repository;

import com.rdp.entity.ReportStatus;
import com.rdp.entity.UserReport;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface UserReportRepository extends JpaRepository<UserReport, Long> {
    List<UserReport> findAllByOrderByCreatedAtDesc();
    long countByStatus(ReportStatus status);
}
