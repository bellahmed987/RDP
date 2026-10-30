package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.ConversationService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.messaging.handler.annotation.*;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.bind.annotation.*;
import com.rdp.service.ImageStorageService;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ChatController {
    private final ConversationService conversations;
    private final SimpMessagingTemplate messaging;
    private final ImageStorageService storage;
    public ChatController(ConversationService conversations, SimpMessagingTemplate messaging, ImageStorageService storage) {
        this.conversations = conversations; this.messaging = messaging; this.storage = storage;
    }
    @GetMapping("/conversations") public List<ConversationView> mine(Authentication auth) {
        return conversations.mine(auth.getName());
    }
    @PostMapping("/requests/{requestId}/conversation")
    public ResponseEntity<ConversationView> open(Authentication auth, @PathVariable Long requestId) {
        return ResponseEntity.ok(conversations.open(auth.getName(), requestId));
    }
    @PostMapping("/donations/{donationId}/conversation")
    public ResponseEntity<ConversationView> contactDonor(Authentication auth, @PathVariable Long donationId) {
        return ResponseEntity.ok(conversations.openForDonation(auth.getName(), donationId));
    }
    @GetMapping("/conversations/{id}/messages")
    public List<MessageView> messages(Authentication auth, @PathVariable Long id) {
        return conversations.messages(auth.getName(), id);
    }
    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<MessageView> send(Authentication auth, @PathVariable Long id, @Valid @RequestBody MessageInput input) {
        return ResponseEntity.status(HttpStatus.CREATED).body(conversations.send(auth.getName(), id, input.body()));
    }
    @PostMapping(value = "/conversations/{id}/voice", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MessageView> voice(Authentication auth, @PathVariable Long id, @RequestPart("file") MultipartFile file) {
        MessageView view = conversations.sendVoice(auth.getName(), id, file);
        messaging.convertAndSend("/topic/conversations/" + id, view);
        return ResponseEntity.status(HttpStatus.CREATED).body(view);
    }
    @PostMapping(value = "/conversations/{id}/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MessageView> image(Authentication auth, @PathVariable Long id, @RequestPart("file") MultipartFile file) {
        MessageView view = conversations.sendImage(auth.getName(), id, file);
        messaging.convertAndSend("/topic/conversations/" + id, view);
        return ResponseEntity.status(HttpStatus.CREATED).body(view);
    }
    @GetMapping("/conversations/{id}/attachments/{filename}")
    public ResponseEntity<Resource> attachment(Authentication auth, @PathVariable Long id, @PathVariable String filename) throws IOException {
        conversations.authorize(id, auth.getName());
        Path path = storage.resolveChatAttachment(filename);
        if (!Files.exists(path)) return ResponseEntity.notFound().build();
        String extension = filename.substring(filename.lastIndexOf('.') + 1);
        if (extension.equals("png")) return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG)
                .cacheControl(CacheControl.noStore()).body(new FileSystemResource(path));
        if (extension.equals("jpg")) return ResponseEntity.ok().contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noStore()).body(new FileSystemResource(path));
        String type = switch (extension) {
            case "mp3" -> "audio/mpeg"; case "ogg" -> "audio/ogg"; case "wav" -> "audio/wav";
            case "webm" -> "audio/webm"; case "aac" -> "audio/aac"; default -> "audio/mp4";
        };
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(type))
                .cacheControl(CacheControl.noStore()).body(new FileSystemResource(path));
    }
    @PostMapping("/conversations/{id}/location")
    public ResponseEntity<MessageView> location(Authentication auth, @PathVariable Long id, @Valid @RequestBody LocationShareInput input) {
        MessageView view = conversations.sendLocation(auth.getName(), id, input);
        messaging.convertAndSend("/topic/conversations/" + id, view);
        return ResponseEntity.status(HttpStatus.CREATED).body(view);
    }
    @MessageMapping("/chat/{conversationId}")
    public void sendLive(@DestinationVariable Long conversationId, @Valid MessageInput input, Authentication auth) {
        MessageView message = conversations.send(auth.getName(), conversationId, input.body());
        messaging.convertAndSend("/topic/conversations/" + conversationId, message);
    }
    @MessageMapping("/calls/{conversationId}")
    public void callSignal(@DestinationVariable Long conversationId, @Payload Map<String, Object> input, Authentication auth) {
        String type = input.get("signalType") == null ? "" : input.get("signalType").toString();
        @SuppressWarnings("unchecked") Map<String, Object> data = input.get("signal") instanceof Map<?, ?> map
                ? (Map<String, Object>) map : Map.of();
        messaging.convertAndSend("/topic/conversations/" + conversationId,
                conversations.callSignal(conversationId, auth.getName(), type, data));
    }
}
