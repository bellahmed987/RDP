package com.rdp.service;

import com.rdp.dto.ApiDtos.DonorProfileView;
import com.rdp.entity.AppUser;
import com.rdp.entity.DonationStatus;
import com.rdp.entity.Role;
import com.rdp.exception.ApiException;
import com.rdp.repository.AppUserRepository;
import com.rdp.repository.DonationRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DonorProfileService {
    private final AppUserRepository users;
    private final DonationRepository donations;

    public DonorProfileService(AppUserRepository users, DonationRepository donations) {
        this.users = users;
        this.donations = donations;
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
}
