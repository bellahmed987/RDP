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
public class RequestService {
    private final DonationRequestRepository requests;
    private final DonationRepository donations;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    private final NotificationService notifications;
    private final RatingRepository ratings;
    public RequestService(DonationRequestRepository requests, DonationRepository donations, CurrentUserService current,
                          ApiMapper mapper, NotificationService notifications, RatingRepository ratings) {
        this.requests = requests; this.donations = donations; this.current = current; this.mapper = mapper; this.notifications = notifications; this.ratings = ratings;
    }
    @Transactional
    public RequestView create(String email, Long donationId, RequestInput input) {
        AppUser recipient = requireRecipient(email);
        Donation donation = findDonation(donationId);
        if (donation.getDonor().getId().equals(recipient.getId())) throw ApiException.forbidden("You cannot request your own donation.");
        if (donation.getStatus() != DonationStatus.AVAILABLE || donation.getAvailableQuantity() < input.quantity())
            throw ApiException.conflict("This donation is not available in that quantity.");
        if (requests.existsByDonationIdAndRecipientId(donationId, recipient.getId()))
            throw ApiException.conflict("You have already requested this donation.");
        DonationRequest request = new DonationRequest();
        request.setDonation(donation); request.setRecipient(recipient); request.setQuantity(input.quantity());
        request.setMessage(input.message() == null ? null : input.message().trim()); request.setStatus(RequestStatus.PENDING);
        request = requests.save(request);
        notifications.create(donation.getDonor(), NotificationType.NEW_REQUEST, "New donation request",
                recipient.getName() + " requested " + donation.getTitle() + ".", request.getId());
        return requestView(request);
    }
    @Transactional(readOnly = true)
    public List<RequestView> mine(String email) {
        AppUser recipient = requireRecipient(email);
        return requests.findByRecipientIdOrderByCreatedAtDesc(recipient.getId()).stream().map(this::requestView).toList();
    }
    @Transactional(readOnly = true)
    public List<RequestView> incoming(String email) {
        AppUser donor = requireDonor(email);
        return requests.findByDonationDonorIdOrderByCreatedAtDesc(donor.getId()).stream().map(this::requestView).toList();
    }
    @Transactional(readOnly = true)
    public List<RequestView> allForAdmin() {
        return requests.findAllByOrderByCreatedAtDesc().stream().map(this::requestView).toList();
    }
    @Transactional(readOnly = true)
    public RequestView get(String email, Long id) {
        AppUser actor = current.require(email);
        DonationRequest request = findRequest(id);
        if (actor.getRole() != Role.ADMIN && !request.getRecipient().getId().equals(actor.getId())
                && !request.getDonation().getDonor().getId().equals(actor.getId()))
            throw ApiException.forbidden("This request is private to its donor and recipient.");
        return requestView(request);
    }
    @Transactional
    public RequestView decide(String email, Long id, RequestStatus decision) {
        AppUser donor = current.require(email);
        if (donor.getRole() != Role.DONOR && donor.getRole() != Role.ADMIN)
            throw ApiException.forbidden("Only donors or administrators can manage incoming requests.");
        DonationRequest request = findRequest(id);
        Donation donation = request.getDonation();
        if (donor.getRole() != Role.ADMIN && !donation.getDonor().getId().equals(donor.getId()))
            throw ApiException.forbidden("This request belongs to another donor.");
        if (request.getStatus() != RequestStatus.PENDING) throw ApiException.conflict("Only pending requests can be accepted or rejected.");
        if (decision != RequestStatus.ACCEPTED && decision != RequestStatus.REJECTED)
            throw ApiException.badRequest("Choose ACCEPTED or REJECTED.");
        if (decision == RequestStatus.ACCEPTED) {
            if (donation.getStatus() != DonationStatus.AVAILABLE || donation.getAvailableQuantity() < request.getQuantity())
                throw ApiException.conflict("There is no longer enough available quantity.");
            donation.setAvailableQuantity(donation.getAvailableQuantity() - request.getQuantity());
            // An accepted pickup reserves the whole listing until pickup is completed.
            donation.setStatus(DonationStatus.RESERVED);
            notifications.create(request.getRecipient(), NotificationType.REQUEST_ACCEPTED,
                    "Request accepted", "The donor accepted your request for " + donation.getTitle() + ".", request.getId());
        } else {
            notifications.create(request.getRecipient(), NotificationType.REQUEST_REJECTED,
                    "Request not accepted", "The donor could not accept your request for " + donation.getTitle() + ".", request.getId());
        }
        request.setStatus(decision);
        return requestView(request);
    }
    @Transactional
    public RequestView cancel(String email, Long id) {
        AppUser recipient = requireRecipient(email);
        DonationRequest request = findRequest(id);
        if (!request.getRecipient().getId().equals(recipient.getId())) throw ApiException.forbidden("This request belongs to another recipient.");
        if (request.getStatus() != RequestStatus.PENDING) throw ApiException.conflict("Only a pending request can be cancelled.");
        request.setStatus(RequestStatus.CANCELLED);
        return requestView(request);
    }
    @Transactional
    public RequestView complete(String email, Long id) {
        AppUser donor = current.require(email);
        if (donor.getRole() != Role.DONOR && donor.getRole() != Role.ADMIN)
            throw ApiException.forbidden("Only donors or administrators can complete pickups.");
        DonationRequest request = findRequest(id);
        Donation donation = request.getDonation();
        if (donor.getRole() != Role.ADMIN && !donation.getDonor().getId().equals(donor.getId()))
            throw ApiException.forbidden("This request belongs to another donor.");
        if (request.getStatus() != RequestStatus.ACCEPTED) throw ApiException.conflict("Only an accepted pickup can be completed.");
        request.setStatus(RequestStatus.COMPLETED);
        if (donation.getAvailableQuantity() == 0) donation.setStatus(DonationStatus.PICKED_UP);
        else if (requests.existsByDonationIdAndStatusAndIdNot(donation.getId(), RequestStatus.ACCEPTED, request.getId()))
            donation.setStatus(DonationStatus.RESERVED);
        else donation.setStatus(DonationStatus.AVAILABLE);
        notifications.create(request.getRecipient(), NotificationType.DONATION_UPDATE,
                "Pickup completed", "The donor marked " + donation.getTitle() + " as picked up.", request.getId());
        return requestView(request);
    }
    private AppUser requireRecipient(String email) {
        AppUser user = current.require(email);
        if (user.getRole() != Role.RECIPIENT) throw ApiException.forbidden("Only recipient accounts can make requests.");
        return user;
    }
    private AppUser requireDonor(String email) {
        AppUser user = current.require(email);
        if (user.getRole() != Role.DONOR) throw ApiException.forbidden("Only donor accounts can manage incoming requests.");
        return user;
    }
    private Donation findDonation(Long id) { return donations.findById(id).orElseThrow(() -> ApiException.notFound("Donation not found.")); }
    private DonationRequest findRequest(Long id) { return requests.findById(id).orElseThrow(() -> ApiException.notFound("Request not found.")); }
    private RequestView requestView(DonationRequest request) {
        Long requestId = request.getId();
        return mapper.request(request,
                ratings.existsByRequestIdAndReviewerId(requestId, request.getDonation().getDonor().getId()),
                ratings.existsByRequestIdAndReviewerId(requestId, request.getRecipient().getId()));
    }
}
