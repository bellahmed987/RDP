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
        AppUser recipient = current.require(email);
        if (recipient.getRole() != Role.RECIPIENT) throw ApiException.forbidden("Only recipients can leave ratings.");
        DonationRequest request = requests.findById(requestId).orElseThrow(() -> ApiException.notFound("Request not found."));
        if (!request.getRecipient().getId().equals(recipient.getId())) throw ApiException.forbidden("This request belongs to another recipient.");
        if (request.getStatus() != RequestStatus.COMPLETED) throw ApiException.conflict("You can rate a donor only after a completed pickup.");
        if (ratings.existsByRequestId(requestId)) throw ApiException.conflict("This pickup already has a rating.");
        Rating rating = new Rating(); rating.setRequest(request); rating.setDonor(request.getDonation().getDonor());
        rating.setRecipient(recipient); rating.setScore(input.score()); rating.setReview(input.review());
        return mapper.rating(ratings.save(rating));
    }
    @Transactional(readOnly = true)
    public List<RatingView> forDonor(Long donorId) {
        return ratings.findByDonorIdOrderByCreatedAtDesc(donorId).stream().map(mapper::rating).toList();
    }
}
