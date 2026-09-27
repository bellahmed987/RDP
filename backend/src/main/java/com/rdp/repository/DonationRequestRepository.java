package com.rdp.repository;

import com.rdp.entity.DonationRequest;
import com.rdp.entity.RequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface DonationRequestRepository extends JpaRepository<DonationRequest, Long> {
    boolean existsByDonationIdAndRecipientId(Long donationId, Long recipientId);
    List<DonationRequest> findByRecipientIdOrderByCreatedAtDesc(Long recipientId);
    List<DonationRequest> findByDonationDonorIdOrderByCreatedAtDesc(Long donorId);
    List<DonationRequest> findByDonationIdOrderByCreatedAtDesc(Long donationId);
    long countByStatus(RequestStatus status);
}
