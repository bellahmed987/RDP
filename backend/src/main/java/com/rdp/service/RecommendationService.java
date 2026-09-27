package com.rdp.service;

import com.rdp.dto.ApiDtos.DonationView;
import com.rdp.entity.*;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class RecommendationService {
    private final DonationRepository donations;
    private final DonationRequestRepository requests;
    private final FavoriteRepository favorites;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    private final DistanceService distance;
    public RecommendationService(DonationRepository donations, DonationRequestRepository requests, FavoriteRepository favorites,
                                 CurrentUserService current, ApiMapper mapper, DistanceService distance) {
        this.donations = donations; this.requests = requests; this.favorites = favorites;
        this.current = current; this.mapper = mapper; this.distance = distance;
    }
    @Transactional(readOnly = true)
    public List<DonationView> recommend(String email, int limit) {
        AppUser user = current.require(email);
        Set<DonationCategory> history = new HashSet<>(user.getPreferredCategories());
        requests.findByRecipientIdOrderByCreatedAtDesc(user.getId()).forEach(r -> history.add(r.getDonation().getCategory()));
        favorites.findByUserIdOrderByCreatedAtDesc(user.getId()).forEach(f -> history.add(f.getDonation().getCategory()));
        List<Donation> candidates = donations.discover(null, null, null, org.springframework.data.domain.PageRequest.of(0, 100)).getContent();
        record Ranked(Donation donation, double score, Double km) {}
        return candidates.stream().map(d -> {
            Double km = user.getLatitude() != null && user.getLongitude() != null && d.getLatitude() != null && d.getLongitude() != null
                    ? distance.km(user.getLatitude(), user.getLongitude(), d.getLatitude(), d.getLongitude()) : null;
            double score = history.contains(d.getCategory()) ? 5.0 : 0.0;
            score += Math.max(0, 3.0 - (System.currentTimeMillis() - d.getCreatedAt().toEpochMilli()) / 86_400_000.0);
            if (km != null) score += Math.max(0, 5.0 - km / 5.0);
            score += Math.min(1.0, d.getAvailableQuantity() / 5.0);
            return new Ranked(d, score, km);
        }).sorted(Comparator.comparingDouble(Ranked::score).reversed())
                .limit(Math.max(1, Math.min(limit, 50)))
                .map(r -> mapper.donation(r.donation(), r.km(), favorites.findByUserIdAndDonationId(user.getId(), r.donation().getId()).isPresent()))
                .toList();
    }
}
