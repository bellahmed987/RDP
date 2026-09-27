package com.rdp.websocket;

import com.rdp.security.*;
import com.rdp.service.ConversationService;
import io.jsonwebtoken.JwtException;
import org.springframework.messaging.*;
import org.springframework.messaging.simp.stomp.*;
import org.springframework.messaging.support.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import java.util.regex.*;

@Component
public class ChatChannelInterceptor implements ChannelInterceptor {
    private static final Pattern CHAT_DESTINATION = Pattern.compile("^/(?:topic/conversations|app/chat)/(\\d+)$");
    private final JwtService jwt;
    private final RdpUserDetailsService users;
    private final ConversationService conversations;
    public ChatChannelInterceptor(JwtService jwt, RdpUserDetailsService users, ConversationService conversations) {
        this.jwt = jwt; this.users = users; this.conversations = conversations;
    }
    @Override public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) return message;
        StompCommand command = accessor.getCommand();
        if (command == StompCommand.CONNECT) {
            String authorization = accessor.getFirstNativeHeader("Authorization");
            if (authorization == null || !authorization.startsWith("Bearer "))
                throw new MessageDeliveryException(message, "A bearer token is required for chat.");
            try {
                UserDetails details = users.loadUserByUsername(jwt.subject(authorization.substring(7)));
                if (!details.isEnabled()) throw new MessageDeliveryException(message, "This account is inactive.");
                accessor.setUser(new UsernamePasswordAuthenticationToken(details, null, details.getAuthorities()));
            } catch (JwtException | IllegalArgumentException ex) {
                throw new MessageDeliveryException(message, "The chat token is invalid or expired.");
            }
        }
        if (command == StompCommand.SUBSCRIBE || command == StompCommand.SEND) {
            String destination = accessor.getDestination();
            Matcher matcher = destination == null ? null : CHAT_DESTINATION.matcher(destination);
            if (matcher == null || !matcher.matches())
                throw new MessageDeliveryException(message, "Only private conversation destinations are allowed.");
            if (accessor.getUser() == null) throw new MessageDeliveryException(message, "Authentication is required.");
            conversations.authorize(Long.parseLong(matcher.group(1)), accessor.getUser().getName());
            if (command == StompCommand.SEND && !destination.startsWith("/app/chat/"))
                throw new MessageDeliveryException(message, "Messages must be sent to the application destination.");
            if (command == StompCommand.SUBSCRIBE && !destination.startsWith("/topic/conversations/"))
                throw new MessageDeliveryException(message, "Subscribe to the conversation topic.");
        }
        return message;
    }
}
