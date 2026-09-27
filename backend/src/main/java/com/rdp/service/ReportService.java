package com.rdp.service;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class ReportService {
    private final UserReportRepository reports;
    private final AppUserRepository users;
    private final DonationRepository donations;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    public ReportService(UserReportRepository reports, AppUserRepository users, DonationRepository donations,
                         CurrentUserService current, ApiMapper mapper) {
        this.reports = reports; this.users = users; this.donations = donations; this.current = current; this.mapper = mapper;
    }
    @Transactional
    public ReportView create(String email, ReportInput input) {
        AppUser reporter = current.require(email);
        if ((input.reportedUserId() == null) == (input.donationId() == null))
            throw ApiException.badRequest("Report either a user or a donation.");
        UserReport report = new UserReport(); report.setReporter(reporter); report.setReason(input.reason().trim());
        report.setDetails(input.details() == null ? null : input.details().trim());
        if (input.reportedUserId() != null) {
            if (input.reportedUserId().equals(reporter.getId())) throw ApiException.badRequest("You cannot report your own account.");
            report.setReportedUser(users.findById(input.reportedUserId()).orElseThrow(() -> ApiException.notFound("User not found.")));
        } else {
            report.setDonation(donations.findById(input.donationId()).orElseThrow(() -> ApiException.notFound("Donation not found.")));
        }
        return mapper.report(reports.save(report));
    }
    @Transactional(readOnly = true)
    public List<ReportView> all() { return reports.findAllByOrderByCreatedAtDesc().stream().map(mapper::report).toList(); }
    @Transactional
    public ReportView update(Long id, ReportStatus status) {
        UserReport report = reports.findById(id).orElseThrow(() -> ApiException.notFound("Report not found."));
        report.setStatus(status);
        return mapper.report(report);
    }
}
