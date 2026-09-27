package com.rdp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApiIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @Test
    void donorCanPublishAndPublicCanDiscoverButRecipientCannotPublish() throws Exception {
        String donor = register("donor", "DONOR");
        String recipient = register("recipient", "RECIPIENT");
        String donation = """
                {"title":"Winter coat","category":"CLOTHING","description":"Warm clean coat","condition":"GOOD",
                "quantity":2,"pickupAddress":"Community centre","city":"Lahore","latitude":31.5204,"longitude":74.3587}
                """;
        String response = mvc.perform(post("/api/donations").header("Authorization", "Bearer " + donor)
                        .contentType(MediaType.APPLICATION_JSON).content(donation))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.title").value("Winter coat"))
                .andReturn().getResponse().getContentAsString();
        long id = json.readTree(response).get("id").asLong();

        mvc.perform(get("/api/donations"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].title").value("Winter coat"));

        mvc.perform(post("/api/donations/" + id + "/requests").header("Authorization", "Bearer " + recipient)
                        .contentType(MediaType.APPLICATION_JSON).content("""
                                {"quantity":1,"message":"Please"}
                                """))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("PENDING"));

        mvc.perform(post("/api/donations").header("Authorization", "Bearer " + recipient)
                        .contentType(MediaType.APPLICATION_JSON).content(donation))
                .andExpect(status().isForbidden());
    }

    @Test
    void invalidRegistrationIsRejectedAndAdminRoleCannotBeSelfAssigned() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"No admin","email":"bad-admin@example.test","password":"not-a-long-password","role":"ADMIN"}
                                """))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Bad","email":"bad@example.test","password":"short","role":"DONOR"}
                                """))
                .andExpect(status().isBadRequest());
    }

    private String register(String suffix, String role) throws Exception {
        String body = json.writeValueAsString(Map.of("name", "Test " + suffix, "email", suffix + "@example.test",
                "password", "correct-horse-battery", "role", role, "city", "Lahore"));
        String response = mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        JsonNode node = json.readTree(response);
        String token = node.get("token").asText();
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.role").value(role));
        return token;
    }
}
