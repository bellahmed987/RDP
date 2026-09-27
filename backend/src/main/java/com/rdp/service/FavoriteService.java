package com.rdp.service;

import com.rdp.dto.ApiDtos.DonationView;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class FavoriteService {
    private final FavoriteRepository favorites;
    private final DonationRepository donations;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    public FavoriteService(FavoriteRepository favorites, DonationRepository donations, CurrentUserService current, ApiMapper mapper) {
        this.favorites = favorites; this.donations = donations; this.current = current; this.mapper = mapper;
    }
    @Transactional
    public void add(String email, Long donationId) {
        AppUser user = recipient(email);
        Donation donation = donations.findById(donationId).orElseThrow(() -> ApiException.notFound("Donation not found."));
        if (donation.getStatus() != DonationStatus.AVAILABLE) throw ApiException.conflict("Only available donations can be saved.");
        if (favorites.findByUserIdAndDonationId(user.getId(), donationId).isEmpty()) {
            Favorite favorite = new Favorite(); favorite.setUser(user); favorite.setDonation(donation); favorites.save(favorite);
        }
    }
    @Transactional
    public void remove(String email, Long donationId) {
        AppUser user = recipient(email);
        favorites.findByUserIdAndDonationId(user.getId(), donationId).ifPresent(favorites::delete);
    }
    @Transactional(readOnly = true)
    public List<DonationView> mine(String email) {
        AppUser user = recipient(email);
        return favorites.findByUserIdOrderByCreatedAtDesc(user.getId()).stream()
                .filter(f -> f.getDonation().getStatus() == DonationStatus.AVAILABLE)
                .map(f -> mapper.donation(f.getDonation(), null, true)).toList();
    }
    private AppUser recipient(String email) {
        AppUser user = current.require(email);
        if (user.getRole() != Role.RECIPIENT) throw ApiException.forbidden("Only recipient accounts can save donations.");
        return user;
    }
}
