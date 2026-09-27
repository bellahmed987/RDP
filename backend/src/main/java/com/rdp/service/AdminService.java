package com.rdp.service;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.*;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.Arrays;

@Service
public class AdminService {
    private final AppUserRepository users;
    private final DonationRepository donations;
    private final DonationRequestRepository requests;
    private final UserReportRepository reports;
    private final ApiMapper mapper;
    private final NotificationService notifications;
    private final DonationService donationService;
    public AdminService(AppUserRepository users, DonationRepository donations, DonationRequestRepository requests,
                        UserReportRepository reports, ApiMapper mapper, NotificationService notifications,
                        DonationService donationService) {
        this.users = users; this.donations = donations; this.requests = requests; this.reports = reports;
        this.mapper = mapper; this.notifications = notifications; this.donationService = donationService;
    }
    @Transactional(readOnly = true)
    public PageView<UserView> users(String q, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<AppUser> result = q == null || q.isBlank() ? users.findAll(pageable)
                : users.findByNameContainingIgnoreCaseOrEmailContainingIgnoreCase(q.trim(), q.trim(), pageable);
        return new PageView<>(result.getContent().stream().map(mapper::user).toList(), result.getNumber(),
                result.getSize(), result.getTotalElements(), result.getTotalPages());
    }
    @Transactional
    public UserView status(Long id, AccountStatus status) {
        AppUser user = users.findById(id).orElseThrow(() -> ApiException.notFound("User not found."));
        if (user.getRole() == Role.ADMIN && status != AccountStatus.ACTIVE)
            throw ApiException.badRequest("The development admin cannot be suspended or banned through this screen.");
        user.setStatus(status);
        notifications.create(user, NotificationType.ADMIN_ACTION, "Account status updated",
                "An administrator changed your account status to " + status + ".", user.getId());
        return mapper.user(user);
    }
    public java.util.List<DonationView> donations() { return donationService.allAdmin(); }
    public DonationView donation(Long id) { return donationService.findAdmin(id); }
    public AdminStats stats() {
        return new AdminStats(users.count(), users.countByRole(Role.DONOR), users.countByRole(Role.RECIPIENT),
                users.countByStatus(AccountStatus.ACTIVE), donations.count(),
                donations.countByStatus(DonationStatus.AVAILABLE), donations.countByStatus(DonationStatus.PICKED_UP),
                requests.countByStatus(RequestStatus.PENDING), reports.countByStatus(ReportStatus.OPEN),
                Arrays.stream(DonationCategory.values()).map(c ->
                        new CategoryCount(c.name(), donations.countByCategory(c))).toList());
    }
}
