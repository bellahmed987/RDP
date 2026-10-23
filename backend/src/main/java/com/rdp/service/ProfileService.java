package com.rdp.service;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.*;
import com.rdp.exception.ApiException;
import com.rdp.mapper.ApiMapper;
import com.rdp.repository.AppUserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ProfileService {
    private final AppUserRepository users;
    private final ApiMapper mapper;
    private final ImageStorageService storage;
    public ProfileService(AppUserRepository users, ApiMapper mapper, ImageStorageService storage) { this.users = users; this.mapper = mapper; this.storage = storage; }
    @Transactional(readOnly = true)
    public UserView get(String email) {
        return mapper.user(users.findByEmailIgnoreCase(email).orElseThrow(() -> ApiException.notFound("Account not found.")));
    }
    @Transactional
    public UserView update(String email, ProfileUpdate input) {
        AppUser user = users.findByEmailIgnoreCase(email).orElseThrow(() -> ApiException.notFound("Account not found."));
        if (input.name() != null) user.setName(input.name().trim());
        if (input.phone() != null) user.setPhone(input.phone().trim());
        if (input.address() != null) user.setAddress(input.address().trim());
        if (input.city() != null) user.setCity(input.city().trim());
        if (input.latitude() != null) user.setLatitude(input.latitude());
        if (input.longitude() != null) user.setLongitude(input.longitude());
        if (input.profileImageUrl() != null) user.setProfileImageUrl(input.profileImageUrl());
        if (input.preferredCategories() != null && user.getRole() == Role.RECIPIENT)
            user.setPreferredCategories(input.preferredCategories().stream().distinct().toList());
        return mapper.user(user);
    }
    @Transactional
    public UserView uploadPhoto(String email, MultipartFile file) {
        AppUser user = users.findByEmailIgnoreCase(email).orElseThrow(() -> ApiException.notFound("Account not found."));
        user.setProfileImageUrl(storage.store(file));
        return mapper.user(user);
    }
}
