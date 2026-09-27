package com.rdp.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.rdp.service.FirebasePushGateway;
import com.rdp.service.NoOpPushGateway;
import com.rdp.service.PushGateway;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.FileInputStream;
import java.io.IOException;

@Configuration
public class PushConfiguration {
    @Bean
    @ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "false", matchIfMissing = true)
    PushGateway noOpPushGateway() { return new NoOpPushGateway(); }

    @Bean
    @ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
    FirebaseMessaging firebaseMessaging(@Value("$" + "{app.firebase.credentials}") String credentialPath) throws IOException {
        if (credentialPath == null || credentialPath.isBlank()) {
            throw new IllegalStateException("FCM_ENABLED=true requires FIREBASE_CREDENTIALS to point to a Firebase service-account JSON file.");
        }
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(new FileInputStream(credentialPath)))
                .build();
        FirebaseApp app = FirebaseApp.initializeApp(options, "rdp");
        return FirebaseMessaging.getInstance(app);
    }

    @Bean
    @ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
    PushGateway firebasePushGateway(FirebaseMessaging messaging) { return new FirebasePushGateway(messaging); }
}
