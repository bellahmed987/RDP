package com.rdp.repository;

import com.rdp.entity.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface DonationRepository extends JpaRepository<Donation, Long> {
    @Query("""
        select d from Donation d
        where d.status = com.rdp.entity.DonationStatus.AVAILABLE
          and d.availableQuantity > 0
          and (:category is null or d.category = :category)
          and (:city is null or lower(d.city) = lower(:city))
          and (:q is null or lower(d.title) like lower(concat('%', :q, '%'))
               or lower(d.description) like lower(concat('%', :q, '%')))
        """)
    Page<Donation> discover(@Param("category") DonationCategory category, @Param("city") String city,
                            @Param("q") String query, Pageable pageable);
    List<Donation> findByDonorIdOrderByCreatedAtDesc(Long donorId);
    long countByStatus(DonationStatus status);
    long countByCategory(DonationCategory category);
    long countByCityIgnoreCase(String city);
}
