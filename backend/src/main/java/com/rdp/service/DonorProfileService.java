package com.rdp.service;

import com.rdp.dto.ApiDtos.DonorProfileView;
import com.rdp.dto.ApiDtos.PublicProfileView;
import com.rdp.entity.AppUser;
import com.rdp.entity.DonationStatus;
import com.rdp.entity.Role;
import com.rdp.exception.ApiException;
import com.rdp.repository.AppUserRepository;
import com.rdp.repository.DonationRepository;
import com.rdp.repository.DonationRequestRepository;
import com.rdp.repository.RatingRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DonorProfileService {
    private final AppUserRepository users;
    private final DonationRepository donations;
    private final DonationRequestRepository requests;
    private final RatingRepository ratings;

    public DonorProfileService(AppUserRepository users, DonationRepository donations,
                               DonationRequestRepository requests, RatingRepository ratings) {
        this.users = users;
        this.donations = donations;
        this.requests = requests;
        this.ratings = ratings;
    }

    @Transactional(readOnly = true)
    public DonorProfileView get(Long donorId) {
        AppUser donor = users.findById(donorId)
                .filter(user -> user.getRole() == Role.DONOR)
                .orElseThrow(() -> ApiException.notFound("Donor profile not found."));
        return new DonorProfileView(donor.getId(), donor.getName(), donor.getProfileImageUrl(), donor.getCity(),
                donor.getCreatedAt(), donations.countByDonorId(donorId),
                donations.countByDonorIdAndStatus(donorId, DonationStatus.PICKED_UP));
    }

    @Transactional(readOnly = true)
    public PublicProfileView getPublic(Long userId) {
        AppUser user = users.findById(userId)
                .filter(u -> u.getRole() == Role.DONOR || u.getRole() == Role.RECIPIENT)
                .orElseThrow(() -> ApiException.notFound("Profile not found."));
        long listings = user.getRole() == Role.DONOR ? donations.countByDonorId(userId) : 0;
        long completed = user.getRole() == Role.DONOR
                ? donations.countByDonorIdAndStatus(userId, DonationStatus.PICKED_UP)
                : requests.countByRecipientIdAndStatus(userId, com.rdp.entity.RequestStatus.COMPLETED);
        return new PublicProfileView(user.getId(), user.getName(), user.getProfileImageUrl(), user.getCity(),
                user.getRole(), user.getCreatedAt(), listings, completed,
                ratings.countByTargetId(userId), ratings.averageForTarget(userId));
    }
}
