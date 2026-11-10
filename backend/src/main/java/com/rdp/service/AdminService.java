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
    private final AdminRoleChangeRepository roleChanges;
    public AdminService(AppUserRepository users, DonationRepository donations, DonationRequestRepository requests,
                        UserReportRepository reports, ApiMapper mapper, NotificationService notifications,
                        DonationService donationService, AdminRoleChangeRepository roleChanges) {
        this.users = users; this.donations = donations; this.requests = requests; this.reports = reports;
        this.mapper = mapper; this.notifications = notifications; this.donationService = donationService;
        this.roleChanges = roleChanges;
    }
    @Transactional(readOnly = true)
    public PageView<UserView> users(String q, Role role, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<AppUser> result;
        if (q == null || q.isBlank()) result = role == null ? users.findAll(pageable) : users.findByRole(role, pageable);
        else if (role == null) result = users.findByNameContainingIgnoreCaseOrEmailContainingIgnoreCaseOrUsernameContainingIgnoreCase(q.trim(), q.trim(), q.trim(), pageable);
        else result = users.findByRoleAndNameContainingIgnoreCaseOrRoleAndEmailContainingIgnoreCaseOrRoleAndUsernameContainingIgnoreCase(
                role, q.trim(), role, q.trim(), role, q.trim(), pageable);
        return new PageView<>(result.getContent().stream().map(mapper::user).toList(), result.getNumber(),
                result.getSize(), result.getTotalElements(), result.getTotalPages());
    }
    @Transactional
    public UserView status(Long id, AccountStatus status) {
        AppUser user = users.findById(id).orElseThrow(() -> ApiException.notFound("User not found."));
        if (user.getRole() == Role.ADMIN && status != AccountStatus.ACTIVE)
            throw ApiException.badRequest("The development admin cannot be suspended or banned through this screen.");
        if (user.getStatus() == AccountStatus.BANNED && status != AccountStatus.BANNED)
            throw ApiException.conflict("A banned account cannot be reactivated or suspended. Ban is permanent.");
        if (user.getStatus() == status) return mapper.user(user);
        if (status == AccountStatus.SUSPENDED || status == AccountStatus.BANNED)
            restrictOpenRequests(user, status == AccountStatus.BANNED);
        user.setStatus(status);
        notifications.create(user, NotificationType.ADMIN_ACTION, "Account status updated",
                status == AccountStatus.ACTIVE
                        ? "An administrator restored your account. Your active listings are visible again."
                        : status == AccountStatus.SUSPENDED
                                ? "Your account is suspended. Your listings are hidden until an administrator restores access."
                                : "Your account was permanently banned. Its listings are hidden and open requests were cancelled.",
                user.getId());
        return mapper.user(user);
    }

    private void restrictOpenRequests(AppUser user, boolean cancelAccepted) {
        java.util.Set<Long> processed = new java.util.HashSet<>();
        for (DonationRequest request : requests.findByRecipientIdOrderByCreatedAtDesc(user.getId()))
            restrictRequest(request, user, cancelAccepted, processed);
        for (DonationRequest request : requests.findByDonationDonorIdOrderByCreatedAtDesc(user.getId()))
            restrictRequest(request, user, cancelAccepted, processed);
    }

    private void restrictRequest(DonationRequest request, AppUser restrictedUser, boolean cancelAccepted,
                                 java.util.Set<Long> processed) {
        if (!processed.add(request.getId())) return;
        RequestStatus current = request.getStatus();
        if (current != RequestStatus.PENDING && !(cancelAccepted && current == RequestStatus.ACCEPTED)) return;

        if (current == RequestStatus.ACCEPTED) {
            Donation donation = request.getDonation();
            donation.setAvailableQuantity(donation.getAvailableQuantity() + request.getQuantity());
            if (donation.getStatus() == DonationStatus.RESERVED && !donation.isAdminRemoved())
                donation.setStatus(DonationStatus.AVAILABLE);
        }
        request.setStatus(RequestStatus.CANCELLED);
        AppUser otherParty = request.getRecipient().getId().equals(restrictedUser.getId())
                ? request.getDonation().getDonor() : request.getRecipient();
        notifications.create(otherParty, NotificationType.ADMIN_ACTION, "Request cancelled",
                "A request for " + request.getDonation().getTitle()
                        + " was cancelled because an account involved was restricted.", request.getId());
    }
    @Transactional
    public UserView changeRole(String actorEmail, Long targetId, Role newRole) {
        AppUser actor = users.findByEmailIgnoreCase(actorEmail)
                .orElseThrow(() -> ApiException.notFound("Administrator account not found."));
        AppUser target = users.findById(targetId)
                .orElseThrow(() -> ApiException.notFound("User not found."));
        if (actor.getId().equals(target.getId()))
            throw ApiException.badRequest("You cannot change your own administrator role.");
        if (newRole == null || (newRole != Role.ADMIN && newRole != Role.DONOR && newRole != Role.RECIPIENT))
            throw ApiException.badRequest("Choose ADMIN, DONOR, or RECIPIENT.");
        if (target.getRole() == newRole) return mapper.user(target);
        if (newRole == Role.ADMIN && target.getStatus() != AccountStatus.ACTIVE)
            throw ApiException.conflict("Only active accounts can be made app administrators.");
        if (target.getRole() == Role.ADMIN && newRole != Role.ADMIN
                && users.countByRoleAndStatus(Role.ADMIN, AccountStatus.ACTIVE) <= 1)
            throw ApiException.conflict("The last active app administrator cannot be removed.");

        Role previousRole = target.getRole();
        target.setRole(newRole);
        AdminRoleChange change = new AdminRoleChange();
        change.setActor(actor);
        change.setTarget(target);
        change.setPreviousRole(previousRole);
        change.setNewRole(newRole);
        roleChanges.save(change);
        notifications.create(target, NotificationType.ADMIN_ACTION, "Account role updated",
                "Your ShareKind account role was changed to " + newRole + ".", target.getId());
        return mapper.user(target);
    }
    @Transactional(readOnly = true)
    public java.util.List<AdminRoleChangeView> recentRoleChanges() {
        return roleChanges.findTop10ByOrderByCreatedAtDesc().stream()
                .map(change -> new AdminRoleChangeView(change.getId(), change.getActor().getId(),
                        change.getActor().getName(), change.getTarget().getId(), change.getTarget().getName(),
                        change.getPreviousRole(), change.getNewRole(), change.getCreatedAt()))
                .toList();
    }
    public java.util.List<DonationView> donations() { return donationService.allAdmin(); }
    public DonationView donation(Long id) { return donationService.findAdmin(id); }
    public AdminStats stats() {
        return new AdminStats(users.count(), users.countByRole(Role.DONOR), users.countByRole(Role.RECIPIENT),
                users.countByStatus(AccountStatus.ACTIVE), donations.countByAdminRemovedFalse(),
                donations.countByStatus(DonationStatus.AVAILABLE), donations.countByStatus(DonationStatus.PICKED_UP),
                requests.count(), requests.countByStatus(RequestStatus.PENDING), reports.countByStatus(ReportStatus.OPEN),
                Arrays.stream(DonationCategory.values()).map(c ->
                        new CategoryCount(c.name(), donations.countByCategory(c))).toList());
    }
}
