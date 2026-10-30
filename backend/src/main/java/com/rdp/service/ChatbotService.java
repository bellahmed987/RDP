package com.rdp.service;

import com.rdp.dto.ApiDtos.ChatbotReply;
import com.rdp.entity.*;
import com.rdp.repository.DonationRepository;
import com.rdp.repository.DonationRequestRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;

@Service
public class ChatbotService {
    private final ChatbotProvider provider;
    private final CurrentUserService current;
    private final DonationRequestRepository requests;
    private final DonationRepository donations;

    public ChatbotService(ChatbotProvider provider, CurrentUserService current,
                          DonationRequestRepository requests, DonationRepository donations) {
        this.provider = provider;
        this.current = current;
        this.requests = requests;
        this.donations = donations;
    }

    @Transactional(readOnly = true)
    public ChatbotReply reply(String email, String message) {
        AppUser user = current.require(email);
        String question = message.toLowerCase(Locale.ROOT);
        if (asksAboutRequests(question)) return new ChatbotReply(requestSummary(user), "live-requests");
        if (asksAboutAvailableItems(question)) return new ChatbotReply(availableItems(user, question), "live-listings");
        return new ChatbotReply(provider.answer(message), provider.name());
    }

    private boolean asksAboutRequests(String q) {
        return q.contains("request") && (q.contains("my") || q.contains("status") || q.contains("show")
                || q.contains("list") || q.contains("incoming") || q.contains("track") || q.contains("where"));
    }

    private boolean asksAboutAvailableItems(String q) {
        return q.contains("near") || q.contains("available") || q.contains("find item")
                || q.contains("what can i get") || q.contains("what items");
    }

    private String requestSummary(AppUser user) {
        List<DonationRequest> rows = switch (user.getRole()) {
            case RECIPIENT -> requests.findByRecipientIdOrderByCreatedAtDesc(user.getId());
            case DONOR -> requests.findByDonationDonorIdOrderByCreatedAtDesc(user.getId());
            default -> List.of();
        };
        String heading = user.getRole() == Role.DONOR ? "Your incoming requests" : "Your requests";
        if (rows.isEmpty()) return heading + ": there are no requests yet.";
        StringBuilder answer = new StringBuilder(heading).append(" (most recent first):\n");
        rows.stream().limit(6).forEach(request -> answer.append("• ")
                .append(request.getDonation().getTitle()).append(" — ")
                .append(request.getStatus().name().toLowerCase(Locale.ROOT).replace('_', ' '))
                .append(user.getRole() == Role.DONOR
                        ? " (from " + request.getRecipient().getName() + ")"
                        : " (donor: " + request.getDonation().getDonor().getName() + ")")
                .append("\n"));
        return answer.toString().trim();
    }

    private String availableItems(AppUser user, String question) {
        DonationCategory category = findCategory(question);
        var result = donations.discover(category, blankToNull(user.getCity()), null,
                PageRequest.of(0, 5, Sort.by(Sort.Direction.DESC, "createdAt")));
        if (result.isEmpty()) {
            return user.getCity() == null || user.getCity().isBlank()
                    ? "I couldn't find available listings. Add your city to your profile and try again."
                    : "I couldn't find available listings in " + user.getCity() + ". Try another city or check Explore.";
        }
        boolean hasCity = user.getCity() != null && !user.getCity().isBlank();
        StringBuilder answer = new StringBuilder(hasCity
                ? "Available listings in " + user.getCity()
                : "Recent available listings (add your city in Profile for local results)")
                .append(":\n");
        result.getContent().forEach(donation -> answer.append("• ").append(donation.getTitle())
                .append(" (" ).append(donation.getCategory().name().toLowerCase(Locale.ROOT))
                .append(", ").append(donation.getAvailableQuantity()).append(" available, ")
                .append(donation.getCity()).append(")\n"));
        answer.append("Open Explore to see details and request an item.");
        return answer.toString().trim();
    }

    private DonationCategory findCategory(String q) {
        for (DonationCategory category : DonationCategory.values())
            if (q.contains(category.name().toLowerCase(Locale.ROOT))) return category;
        return null;
    }

    private String blankToNull(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
