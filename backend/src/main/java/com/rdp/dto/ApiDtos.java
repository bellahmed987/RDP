package com.rdp.dto;

import com.rdp.entity.*;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

public final class ApiDtos {
    private ApiDtos() {}

    public record RegisterRequest(@NotBlank @Size(max = 120) String name,
                                  @NotBlank @Pattern(regexp = "[A-Za-z0-9_]{3,30}") String username,
                                  @NotBlank @Size(min = 10, max = 72) String password,
                                  @NotNull Role role, @Size(max = 32) String phone,
                                  @Size(max = 100) String city,
                                  @Size(max = 120) String answer1, @Size(max = 120) String answer2,
                                  @Size(max = 120) String answer3, @Size(max = 120) String answer4) {}
    public record LoginRequest(@NotBlank String username, @NotBlank String password) {}
    public record SecurityAnswersInput(@NotBlank String currentPassword,
                                       @NotBlank @Size(max = 120) String answer1,
                                       @NotBlank @Size(max = 120) String answer2,
                                       @NotBlank @Size(max = 120) String answer3,
                                       @NotBlank @Size(max = 120) String answer4) {}
    public record PasswordRecoveryInput(@NotBlank String username,
                                        @NotBlank @Size(max = 120) String answer1,
                                        @NotBlank @Size(max = 120) String answer2,
                                        @NotBlank @Size(max = 120) String answer3,
                                        @NotBlank @Size(max = 120) String answer4,
                                        @NotBlank @Size(min = 10, max = 72) String newPassword) {}
    public record UserView(Long id, String name, String username, String email, String phone, String profileImageUrl,
                           String address, String city, Double latitude, Double longitude,
                           Role role, AccountStatus status, List<DonationCategory> preferredCategories,
                           Instant createdAt) {}
    public record DonorProfileView(Long id, String name, String profileImageUrl, String city,
                                   Instant joinedAt, long listingsPosted, long pickupsCompleted) {}
    public record PublicProfileView(Long id, String name, String profileImageUrl, String city, Role role,
                                    Instant joinedAt, long listingsPosted, long pickupsCompleted,
                                    long reviewsReceived, double averageRating) {}
    public record AuthResponse(String token, String tokenType, UserView user) {}
    public record ProfileUpdate(@Size(max = 120) String name, @Size(max = 32) String phone,
                                @Size(max = 300) String address, @Size(max = 100) String city,
                                @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
                                @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
                                @Size(max = 500) String profileImageUrl,
                                List<DonationCategory> preferredCategories) {}
    public record DonationInput(@NotBlank @Size(max = 140) String title, @NotNull DonationCategory category,
                                @NotBlank @Size(max = 3000) String description,
                                @NotNull ItemCondition condition, @NotNull @Min(1) @Max(10000) Integer quantity,
                                @NotBlank @Size(max = 300) String pickupAddress,
                                @NotBlank @Size(max = 100) String city,
                                @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
                                @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
                                LocalDateTime availableFrom, LocalDateTime availableUntil) {}
    public record DonationView(Long id, Long donorId, String donorName, String donorPhone, String donorCity,
                               String title, DonationCategory category, String description, ItemCondition condition,
                               Integer quantity, Integer availableQuantity, String pickupAddress, String city,
                               Double latitude, Double longitude, LocalDateTime availableFrom,
                               LocalDateTime availableUntil, DonationStatus status, List<String> imageUrls,
                               Instant createdAt, Double distanceKm, boolean favorite) {}
    public record RequestInput(@NotNull @Min(1) Integer quantity, @Size(max = 1000) String message) {}
    public record RequestView(Long id, Long donationId, String donationTitle, Long donorId, String donorName,
                              Long recipientId, String recipientName, Integer quantity, String message,
                              RequestStatus status, Instant createdAt, Instant updatedAt,
                              boolean donorReviewed, boolean recipientReviewed) {}
    public record DecisionInput(@NotNull RequestStatus status) {}
    public record RatingInput(@NotNull @Min(1) @Max(5) Integer score, @Size(max = 1200) String review) {}
    public record RatingView(Long id, Long donationId, String donationTitle, Long donorId, String donorName,
                             Long recipientId, String recipientName, Long reviewerId, String reviewerName,
                             Long targetId, String targetName, Integer score, String review, Instant createdAt) {}
    public record ConversationView(Long id, Long requestId, Long donationId, String donationTitle,
                                   Long otherUserId, String otherUserName, String otherUserProfileImageUrl,
                                   String pickupAddress, Double pickupLatitude, Double pickupLongitude,
                                   Instant createdAt, String lastMessage, MessageKind lastMessageKind,
                                   Instant lastMessageAt, long unreadCount) {}
    public record MessageInput(@NotBlank @Size(max = 4000) String body) {}
    public record MessageView(Long id, Long conversationId, Long senderId, String senderName,
                              String body, MessageKind kind, String attachmentUrl, Double latitude,
                              Double longitude, Instant readAt, Instant createdAt) {}
    public record LocationShareInput(@NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
                                     @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude) {}
    public record NotificationView(Long id, NotificationType type, String title, String body,
                                   Long referenceId, boolean read, Instant createdAt) {}
    public record ReportInput(Long reportedUserId, Long donationId, @NotBlank @Size(max = 100) String reason,
                              @Size(max = 2000) String details) {}
    public record ReportView(Long id, Long reporterId, String reporterName, Long reportedUserId,
                             String reportedUserName, Long donationId, String donationTitle,
                             String reason, String details, ReportStatus status, Instant createdAt) {}
    public record UserStatusInput(@NotNull AccountStatus status) {}
    public record AdminStats(long totalUsers, long donors, long recipients, long activeUsers, long totalDonations,
                             long availableDonations, long completedDonations, long totalRequests, long pendingRequests,
                             long openReports, List<CategoryCount> donationsByCategory) {}
    public record CategoryCount(String category, long count) {}
    public record ChatbotInput(@NotBlank @Size(max = 1000) String message) {}
    public record ChatbotReply(String answer, String provider) {}
    public record PageView<T>(List<T> items, int page, int size, long totalItems, int totalPages) {}
}
