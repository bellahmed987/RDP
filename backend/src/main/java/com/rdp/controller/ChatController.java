package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.ConversationService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.messaging.handler.annotation.*;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api")
public class ChatController {
    private final ConversationService conversations;
    private final SimpMessagingTemplate messaging;
    public ChatController(ConversationService conversations, SimpMessagingTemplate messaging) {
        this.conversations = conversations; this.messaging = messaging;
    }
    @GetMapping("/conversations") public List<ConversationView> mine(Authentication auth) {
        return conversations.mine(auth.getName());
    }
    @PostMapping("/requests/{requestId}/conversation")
    public ResponseEntity<ConversationView> open(Authentication auth, @PathVariable Long requestId) {
        return ResponseEntity.ok(conversations.open(auth.getName(), requestId));
    }
    @GetMapping("/conversations/{id}/messages")
    public List<MessageView> messages(Authentication auth, @PathVariable Long id) {
        return conversations.messages(auth.getName(), id);
    }
    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<MessageView> send(Authentication auth, @PathVariable Long id, @Valid @RequestBody MessageInput input) {
        return ResponseEntity.status(HttpStatus.CREATED).body(conversations.send(auth.getName(), id, input.body()));
    }
    @MessageMapping("/chat/{conversationId}")
    public void sendLive(@DestinationVariable Long conversationId, @Valid MessageInput input, Authentication auth) {
        MessageView message = conversations.send(auth.getName(), conversationId, input.body());
        messaging.convertAndSend("/topic/conversations/" + conversationId, message);
    }
}
