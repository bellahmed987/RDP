package com.rdp.service;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.List;

@Service
public class ConversationService {
    private final ConversationRepository conversations;
    private final ChatMessageRepository messages;
    private final DonationRequestRepository requests;
    private final DonationRepository donations;
    private final CurrentUserService current;
    private final ApiMapper mapper;
    private final NotificationService notifications;
    public ConversationService(ConversationRepository conversations, ChatMessageRepository messages,
            DonationRequestRepository requests, DonationRepository donations, CurrentUserService current,
            ApiMapper mapper, NotificationService notifications) {
        this.conversations = conversations; this.messages = messages; this.requests = requests;
        this.donations = donations;
        this.current = current; this.mapper = mapper; this.notifications = notifications;
    }
    @Transactional
    public ConversationView open(String email, Long requestId) {
        AppUser actor = current.require(email);
        DonationRequest request = requests.findById(requestId).orElseThrow(() -> ApiException.notFound("Request not found."));
        if (!isParticipant(request, actor)) throw ApiException.forbidden("Only the donor and recipient can open this conversation.");
        if (request.getStatus() != RequestStatus.ACCEPTED && request.getStatus() != RequestStatus.COMPLETED)
            throw ApiException.conflict("Chat becomes available after the donor accepts the request.");
        Conversation conversation = conversations.findByDonorIdAndRecipientId(
                        request.getDonation().getDonor().getId(), request.getRecipient().getId())
                .or(() -> conversations.findByRequestId(requestId))
                .orElseGet(() -> {
                    Conversation created = new Conversation();
                    created.setRequest(request);
                    created.setDonation(request.getDonation());
                    created.setDonor(request.getDonation().getDonor());
                    created.setRecipient(request.getRecipient());
                    return conversations.save(created);
                });
        conversation.setRequest(request);
        conversation.setDonation(request.getDonation());
        return view(conversation, actor);
    }

    @Transactional
    public ConversationView openForDonation(String email, Long donationId) {
        AppUser recipient = current.require(email);
        if (recipient.getRole() != Role.RECIPIENT)
            throw ApiException.forbidden("Only recipient accounts can contact a donor before requesting.");
        Donation donation = donations.findById(donationId)
                .orElseThrow(() -> ApiException.notFound("Donation not found."));
        if (donation.getDonor().getId().equals(recipient.getId()))
            throw ApiException.badRequest("You cannot contact yourself about your own listing.");
        if (donation.getStatus() != DonationStatus.AVAILABLE || donation.getAvailableQuantity() < 1)
            throw ApiException.conflict("This listing is no longer available for new conversations.");
        Conversation conversation = conversations.findByDonorIdAndRecipientId(donation.getDonor().getId(), recipient.getId())
                .orElseGet(() -> {
                    Conversation created = new Conversation();
                    created.setDonation(donation);
                    created.setDonor(donation.getDonor());
                    created.setRecipient(recipient);
                    return conversations.save(created);
                });
        conversation.setDonation(donation);
        conversation.setRequest(null);
        return view(conversation, recipient);
    }
    @Transactional(readOnly = true)
    public List<ConversationView> mine(String email) {
        AppUser actor = current.require(email);
        return conversations.findByDonorIdOrRecipientIdOrderByCreatedAtDesc(actor.getId(), actor.getId()).stream()
                .map(c -> view(c, actor)).toList();
    }
    @Transactional
    public List<MessageView> messages(String email, Long conversationId) {
        AppUser actor = current.require(email);
        Conversation c = findConversation(conversationId);
        requireParticipant(c, actor);
        List<ChatMessage> history = messages.findTop100ByConversationIdOrderByCreatedAtAsc(c.getId());
        Instant now = Instant.now();
        history.stream().filter(m -> !m.getSender().getId().equals(actor.getId()) && m.getReadAt() == null)
                .forEach(m -> m.setReadAt(now));
        return history.stream().map(mapper::message).toList();
    }
    @Transactional
    public MessageView send(String email, Long conversationId, String body) {
        AppUser actor = current.require(email);
        Conversation c = findConversation(conversationId);
        requireParticipant(c, actor);
        String text = body == null ? "" : body.trim();
        if (text.isBlank() || text.length() > 4000) throw ApiException.badRequest("A message must contain 1 to 4,000 characters.");
        ChatMessage message = new ChatMessage(); message.setConversation(c); message.setSender(actor); message.setBody(text);
        MessageView view = mapper.message(messages.saveAndFlush(message));
        AppUser recipient = actor.getId().equals(c.getDonor().getId()) ? c.getRecipient() : c.getDonor();
        notifications.create(recipient, NotificationType.NEW_MESSAGE, "New message",
                actor.getName() + " sent you a message about " + donation(c).getTitle() + ".", c.getId());
        return view;
    }
    @Transactional(readOnly = true)
    public void authorize(Long conversationId, String email) {
        requireParticipant(findConversation(conversationId), current.require(email));
    }
    private Conversation findConversation(Long id) {
        return conversations.findById(id).orElseThrow(() -> ApiException.notFound("Conversation not found."));
    }
    private boolean isParticipant(DonationRequest request, AppUser user) {
        return request.getRecipient().getId().equals(user.getId()) || request.getDonation().getDonor().getId().equals(user.getId());
    }
    private void requireParticipant(Conversation c, AppUser user) {
        if (!c.getDonor().getId().equals(user.getId()) && !c.getRecipient().getId().equals(user.getId()))
            throw ApiException.forbidden("This conversation is private to its donor and recipient.");
    }
    private Donation donation(Conversation conversation) {
        return conversation.getDonation() != null
                ? conversation.getDonation()
                : conversation.getRequest().getDonation();
    }
    private ConversationView view(Conversation c, AppUser actor) {
        AppUser other = c.getDonor().getId().equals(actor.getId()) ? c.getRecipient() : c.getDonor();
        Donation donation = donation(c);
        return new ConversationView(c.getId(), c.getRequest() == null ? null : c.getRequest().getId(),
                donation.getId(), donation.getTitle(), other.getId(), other.getName(), c.getCreatedAt());
    }
}
