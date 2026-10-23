package com.rdp.service;

import com.rdp.entity.AppUser;
import com.rdp.entity.UserBlock;
import com.rdp.exception.ApiException;
import com.rdp.repository.AppUserRepository;
import com.rdp.repository.UserBlockRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.Map;

@Service
public class UserBlockService {
    private final AppUserRepository users;
    private final UserBlockRepository blocks;
    private final CurrentUserService current;

    public UserBlockService(AppUserRepository users, UserBlockRepository blocks, CurrentUserService current) {
        this.users = users; this.blocks = blocks; this.current = current;
    }

    @Transactional(readOnly = true)
    public Map<String, Boolean> status(String email, Long otherId) {
        AppUser actor = current.require(email);
        requireOther(otherId, actor);
        return Map.of("blockedByMe", blocks.existsByBlockerIdAndBlockedId(actor.getId(), otherId),
                "blockedYou", blocks.existsByBlockerIdAndBlockedId(otherId, actor.getId()),
                "blocked", isBlockedEither(actor.getId(), otherId));
    }

    @Transactional
    public Map<String, Boolean> block(String email, Long otherId) {
        AppUser actor = current.require(email);
        AppUser other = requireOther(otherId, actor);
        if (!blocks.existsByBlockerIdAndBlockedId(actor.getId(), otherId)) {
            UserBlock row = new UserBlock(); row.setBlocker(actor); row.setBlocked(other); blocks.save(row);
        }
        return status(email, otherId);
    }

    @Transactional
    public Map<String, Boolean> unblock(String email, Long otherId) {
        AppUser actor = current.require(email);
        requireOther(otherId, actor);
        blocks.findByBlockerIdAndBlockedId(actor.getId(), otherId).ifPresent(blocks::delete);
        return status(email, otherId);
    }

    @Transactional(readOnly = true)
    public boolean isBlockedEither(Long userId, Long otherId) {
        return blocks.existsByBlockerIdAndBlockedId(userId, otherId)
                || blocks.existsByBlockerIdAndBlockedId(otherId, userId);
    }

    private AppUser requireOther(Long otherId, AppUser actor) {
        if (otherId.equals(actor.getId())) throw ApiException.badRequest("You cannot block your own account.");
        return users.findById(otherId).orElseThrow(() -> ApiException.notFound("User not found."));
    }
}
