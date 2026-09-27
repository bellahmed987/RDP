package com.rdp.service;

import org.springframework.stereotype.Component;
import java.util.Locale;

@Component
public class LocalHelpChatbot implements ChatbotProvider {
    @Override public String name() { return "local-help"; }
    @Override public String answer(String question) {
        String q = question.toLowerCase(Locale.ROOT);
        if (q.contains("donat") || q.contains("list an item"))
            return "Sign in as a donor, open My Donations, and choose Add donation. Add clear photos, the quantity, condition, and a pickup place and time. Recipients arrange pickup directly with you.";
        if (q.contains("request") || q.contains("recipient"))
            return "Sign in as a recipient, browse available items, open one you need, and choose Request. The donor will review it. You can follow its status in My Requests.";
        if (q.contains("contact") || q.contains("chat") || q.contains("message"))
            return "Open the accepted request and choose Messages. Chat is available only to the donor and recipient involved in that request.";
        if (q.contains("pickup") || q.contains("deliver") || q.contains("delivery"))
            return "RDP does not arrange delivery. After a donor accepts a request, the donor and recipient agree on a safe pickup time and place themselves.";
        if (q.contains("rating") || q.contains("review"))
            return "After the donor marks an accepted request as completed, the recipient can leave one rating from 1 to 5 and an optional review.";
        if (q.contains("favorite") || q.contains("save"))
            return "Tap the bookmark on an available donation to save it. Open Favorites later to find it again.";
        if (q.contains("map") || q.contains("near"))
            return "Allow location access to find nearby donations. You can also search by city. The app can open the pickup coordinates in your map app.";
        return "I can help with donating, requesting an item, pickup arrangements, messages, favorites, maps, and ratings. What would you like to know?";
    }
}
