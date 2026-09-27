package com.rdp.repository;

import com.rdp.entity.Rating;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface RatingRepository extends JpaRepository<Rating, Long> {
    boolean existsByRequestId(Long requestId);
    List<Rating> findByDonorIdOrderByCreatedAtDesc(Long donorId);
    long countByDonorId(Long donorId);
    @org.springframework.data.jpa.repository.Query("select coalesce(avg(r.score),0) from Rating r where r.donor.id = :donorId")
    double averageForDonor(@org.springframework.data.repository.query.Param("donorId") Long donorId);
}
