package com.rdp.service;

import com.rdp.dto.ApiDtos.ChatbotReply;
import org.springframework.stereotype.Service;

@Service
public class ChatbotService {
    private final ChatbotProvider provider;
    public ChatbotService(ChatbotProvider provider) { this.provider = provider; }
    public ChatbotReply reply(String message) { return new ChatbotReply(provider.answer(message), provider.name()); }
}
