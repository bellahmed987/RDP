package com.rdp.repository;

import com.rdp.entity.Favorite;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface FavoriteRepository extends JpaRepository<Favorite, Long> {
    Optional<Favorite> findByUserIdAndDonationId(Long userId, Long donationId);
    List<Favorite> findByUserIdOrderByCreatedAtDesc(Long userId);
    long countByDonationId(Long donationId);
}
