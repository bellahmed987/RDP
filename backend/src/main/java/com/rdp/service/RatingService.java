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
public class RatingService {
    private final RatingRepository ratings;
    private final DonationRequestRepository requests;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    public RatingService(RatingRepository ratings, DonationRequestRepository requests, CurrentUserService current, ApiMapper mapper) {
        this.ratings = ratings; this.requests = requests; this.current = current; this.mapper = mapper;
    }
    @Transactional
    public RatingView create(String email, Long requestId, RatingInput input) {
        AppUser reviewer = current.require(email);
        DonationRequest request = requests.findById(requestId).orElseThrow(() -> ApiException.notFound("Request not found."));
        AppUser donor = request.getDonation().getDonor();
        AppUser recipient = request.getRecipient();
        boolean isDonor = donor.getId().equals(reviewer.getId());
        boolean isRecipient = recipient.getId().equals(reviewer.getId());
        if (!isDonor && !isRecipient) throw ApiException.forbidden("Only the donor or recipient in this pickup can leave a review.");
        if (request.getStatus() != RequestStatus.COMPLETED) throw ApiException.conflict("You can review someone after a completed pickup.");
        if (ratings.existsByRequestIdAndReviewerId(requestId, reviewer.getId()))
            throw ApiException.conflict("You have already reviewed this pickup.");
        Rating rating = new Rating(); rating.setRequest(request); rating.setDonor(request.getDonation().getDonor());
        rating.setRecipient(recipient); rating.setReviewer(reviewer); rating.setTarget(isDonor ? recipient : donor);
        rating.setScore(input.score()); rating.setReview(input.review() == null ? null : input.review().trim());
        return mapper.rating(ratings.save(rating));
    }
    @Transactional(readOnly = true)
    public List<RatingView> forDonor(Long donorId) {
        return forProfile(donorId);
    }
    @Transactional(readOnly = true)
    public List<RatingView> forProfile(Long userId) {
        return ratings.findByTargetIdOrderByCreatedAtDesc(userId).stream().map(mapper::rating).toList();
    }
}
