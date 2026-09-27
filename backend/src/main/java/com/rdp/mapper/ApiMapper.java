package com.rdp.mapper;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import org.springframework.stereotype.Component;
import java.util.List;
import java.util.ArrayList;

@Component
public class ApiMapper {
    public UserView user(AppUser u) {
        return new UserView(u.getId(), u.getName(), u.getEmail(), u.getPhone(), u.getProfileImageUrl(),
                u.getAddress(), u.getCity(), u.getLatitude(), u.getLongitude(), u.getRole(), u.getStatus(),
                new ArrayList<>(u.getPreferredCategories()), u.getCreatedAt());
    }
    public DonationView donation(Donation d, Double distanceKm, boolean favorite) {
        AppUser donor = d.getDonor();
        return new DonationView(d.getId(), donor.getId(), donor.getName(), donor.getPhone(), donor.getCity(),
                d.getTitle(), d.getCategory(), d.getDescription(), d.getCondition(), d.getQuantity(),
                d.getAvailableQuantity(), d.getPickupAddress(), d.getCity(), d.getLatitude(), d.getLongitude(),
                d.getAvailableFrom(), d.getAvailableUntil(), d.getStatus(), List.copyOf(d.getImageUrls()),
                d.getCreatedAt(), distanceKm, favorite);
    }
    public RequestView request(DonationRequest r) {
        return new RequestView(r.getId(), r.getDonation().getId(), r.getDonation().getTitle(),
                r.getDonation().getDonor().getId(), r.getDonation().getDonor().getName(),
                r.getRecipient().getId(), r.getRecipient().getName(), r.getQuantity(), r.getMessage(),
                r.getStatus(), r.getCreatedAt(), r.getUpdatedAt());
    }
    public RatingView rating(Rating r) {
        return new RatingView(r.getId(), r.getRequest().getDonation().getId(), r.getRequest().getDonation().getTitle(),
                r.getDonor().getId(), r.getDonor().getName(), r.getRecipient().getId(), r.getRecipient().getName(),
                r.getScore(), r.getReview(), r.getCreatedAt());
    }
    public MessageView message(ChatMessage m) {
        return new MessageView(m.getId(), m.getConversation().getId(), m.getSender().getId(),
                m.getSender().getName(), m.getBody(), m.getReadAt(), m.getCreatedAt());
    }
    public NotificationView notification(AppNotification n) {
        return new NotificationView(n.getId(), n.getType(), n.getTitle(), n.getBody(),
                n.getReferenceId(), n.isRead(), n.getCreatedAt());
    }
    public ReportView report(UserReport r) {
        return new ReportView(r.getId(), r.getReporter().getId(), r.getReporter().getName(),
                r.getReportedUser() == null ? null : r.getReportedUser().getId(),
                r.getReportedUser() == null ? null : r.getReportedUser().getName(),
                r.getDonation() == null ? null : r.getDonation().getId(),
                r.getDonation() == null ? null : r.getDonation().getTitle(),
                r.getReason(), r.getDetails(), r.getStatus(), r.getCreatedAt());
    }
}
