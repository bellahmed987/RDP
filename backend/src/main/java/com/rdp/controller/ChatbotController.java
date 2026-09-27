package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.service.ChatbotService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chatbot")
public class ChatbotController {
    private final ChatbotService chatbot;
    public ChatbotController(ChatbotService chatbot) { this.chatbot = chatbot; }
    @PostMapping public ChatbotReply reply(@Valid @RequestBody ChatbotInput input) { return chatbot.reply(input.message()); }
}
