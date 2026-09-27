package com.rdp.service;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.*;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class DonationService {
    private final DonationRepository donations;
    private final DonationRequestRepository requests;
    private final FavoriteRepository favorites;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    private final DistanceService distance;
    private final NotificationService notifications;

    public DonationService(DonationRepository donations, DonationRequestRepository requests, FavoriteRepository favorites,
                           CurrentUserService current, ApiMapper mapper, DistanceService distance, NotificationService notifications) {
        this.donations = donations; this.requests = requests; this.favorites = favorites;
        this.current = current; this.mapper = mapper; this.distance = distance; this.notifications = notifications;
    }

    @Transactional
    public DonationView create(String email, DonationInput input) {
        AppUser donor = requireDonor(email);
        Donation d = new Donation();
        d.setDonor(donor);
        apply(d, input);
        d.setAvailableQuantity(input.quantity());
        d.setStatus(DonationStatus.AVAILABLE);
        return mapper.donation(donations.save(d), null, false);
    }

    @Transactional(readOnly = true)
    public PageView<DonationView> discover(String email, String query, DonationCategory category, String city, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 50)), Sort.by(Sort.Direction.DESC, "createdAt"));
        Long userId = optionalUserId(email);
        Page<Donation> result = donations.discover(category, blankToNull(city), blankToNull(query), pageable);
        return new PageView<>(result.getContent().stream().map(d ->
                mapper.donation(d, null, isFavorite(userId, d.getId()))).toList(), result.getNumber(),
                result.getSize(), result.getTotalElements(), result.getTotalPages());
    }

    @Transactional(readOnly = true)
    public PageView<DonationView> nearby(String email, double latitude, double longitude, double radiusKm,
                                         DonationCategory category, int page, int size) {
        if (radiusKm <= 0 || radiusKm > 100) throw ApiException.badRequest("Radius must be between 0 and 100 km.");
        List<DonationView> all = donations.discover(category, null, null, PageRequest.of(0, 1000)).getContent().stream()
                .filter(d -> d.getLatitude() != null && d.getLongitude() != null)
                .map(d -> {
                    double km = distance.km(latitude, longitude, d.getLatitude(), d.getLongitude());
                    return new AbstractMap.SimpleEntry<>(d, km);
                }).filter(e -> e.getValue() <= radiusKm)
                .sorted(Map.Entry.comparingByValue()).map(e -> mapper.donation(e.getKey(), e.getValue(),
                        isFavorite(optionalUserId(email), e.getKey().getId()))).toList();
        int safeSize = Math.max(1, Math.min(size, 50));
        int safePage = Math.max(0, page);
        int from = Math.min(safePage * safeSize, all.size());
        int to = Math.min(from + safeSize, all.size());
        return new PageView<>(all.subList(from, to), safePage, safeSize, all.size(),
                all.isEmpty() ? 0 : (int) Math.ceil((double) all.size() / safeSize));
    }

    @Transactional(readOnly = true)
    public DonationView get(String email, Long id) {
        Donation donation = find(id);
        Long userId = optionalUserId(email);
        return mapper.donation(donation, null, isFavorite(userId, id));
    }

    @Transactional(readOnly = true)
    public List<DonationView> mine(String email) {
        AppUser donor = requireDonor(email);
        return donations.findByDonorIdOrderByCreatedAtDesc(donor.getId()).stream()
                .map(d -> mapper.donation(d, null, false)).toList();
    }

    @Transactional
    public DonationView update(String email, Long id, DonationInput input) {
        AppUser donor = requireDonor(email);
        Donation d = find(id);
        requireOwner(d, donor);
        if (d.getStatus() != DonationStatus.AVAILABLE)
            throw ApiException.conflict("Only an available donation can be edited.");
        int reserved = requests.findByDonationIdOrderByCreatedAtDesc(id).stream()
                .filter(r -> r.getStatus() == RequestStatus.ACCEPTED || r.getStatus() == RequestStatus.COMPLETED)
                .mapToInt(DonationRequest::getQuantity).sum();
        if (input.quantity() < reserved) throw ApiException.badRequest("Quantity cannot be lower than already accepted requests.");
        apply(d, input);
        d.setAvailableQuantity(input.quantity() - reserved);
        return mapper.donation(d, null, false);
    }

    @Transactional
    public void cancel(String email, Long id) {
        AppUser donor = requireDonor(email);
        Donation d = find(id);
        requireOwner(d, donor);
        if (d.getStatus() == DonationStatus.PICKED_UP || d.getStatus() == DonationStatus.CANCELLED)
            throw ApiException.conflict("This donation is already closed.");
        if (requests.findByDonationIdOrderByCreatedAtDesc(id).stream().anyMatch(r -> r.getStatus() == RequestStatus.ACCEPTED))
            throw ApiException.conflict("Resolve the accepted pickup request before cancelling this donation.");
        d.setStatus(DonationStatus.CANCELLED);
        requests.findByDonationIdOrderByCreatedAtDesc(id).stream().filter(r -> r.getStatus() == RequestStatus.PENDING)
                .forEach(r -> r.setStatus(RequestStatus.REJECTED));
    }

    @Transactional
    public DonationView addImage(String email, Long id, String imageUrl) {
        AppUser donor = requireDonor(email);
        Donation d = find(id);
        requireOwner(d, donor);
        if (d.getImageUrls().size() >= 5) throw ApiException.badRequest("A donation can have up to 5 photos.");
        d.getImageUrls().add(imageUrl);
        return mapper.donation(d, null, false);
    }

    @Transactional
    public void adminRemove(Long id) {
        Donation d = find(id);
        d.setStatus(DonationStatus.CANCELLED);
        requests.findByDonationIdOrderByCreatedAtDesc(id).stream().filter(r ->
                r.getStatus() == RequestStatus.PENDING || r.getStatus() == RequestStatus.ACCEPTED)
                .forEach(r -> {
                    r.setStatus(RequestStatus.REJECTED);
                    notifications.create(r.getRecipient(), NotificationType.DONATION_UPDATE,
                            "Donation removed", "An administrator removed a donation in one of your requests.", r.getId());
                });
        notifications.create(d.getDonor(), NotificationType.ADMIN_ACTION,
                "Donation removed", "An administrator removed your donation after moderation.", d.getId());
    }

    @Transactional(readOnly = true)
    public List<DonationView> allAdmin() {
        return donations.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
                .map(d -> mapper.donation(d, null, false)).toList();
    }

    public DonationView findAdmin(Long id) {
        return mapper.donation(find(id), null, false);
    }

    private AppUser requireDonor(String email) {
        AppUser user = current.require(email);
        if (user.getRole() != Role.DONOR) throw ApiException.forbidden("Only donor accounts can manage donations.");
        return user;
    }
    private Donation find(Long id) { return donations.findById(id).orElseThrow(() -> ApiException.notFound("Donation not found.")); }
    private void requireOwner(Donation d, AppUser user) {
        if (!d.getDonor().getId().equals(user.getId())) throw ApiException.forbidden("This donation belongs to another donor.");
    }
    private void apply(Donation d, DonationInput i) {
        d.setTitle(i.title().trim()); d.setCategory(i.category()); d.setDescription(i.description().trim());
        d.setCondition(i.condition()); d.setQuantity(i.quantity()); d.setPickupAddress(i.pickupAddress().trim());
        d.setCity(i.city().trim()); d.setLatitude(i.latitude()); d.setLongitude(i.longitude());
        d.setAvailableFrom(i.availableFrom()); d.setAvailableUntil(i.availableUntil());
    }
    private Long optionalUserId(String email) {
        if (email == null || email.isBlank()) return null;
        return usersId(email);
    }
    private Long usersId(String email) {
        try { return current.require(email).getId(); } catch (ApiException ex) { return null; }
    }
    private boolean isFavorite(Long userId, Long donationId) {
        return userId != null && favorites.findByUserIdAndDonationId(userId, donationId).isPresent();
    }
    private String blankToNull(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
