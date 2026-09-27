package com.rdp.controller;

import com.rdp.dto.ApiDtos.DonationView;
import com.rdp.service.RecommendationService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/recommendations")
public class RecommendationController {
    private final RecommendationService recommendations;
    public RecommendationController(RecommendationService recommendations) { this.recommendations = recommendations; }
    @GetMapping public List<DonationView> recommend(Authentication auth, @RequestParam(defaultValue = "20") int limit) {
        return recommendations.recommend(auth.getName(), limit);
    }
}
