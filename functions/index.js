const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendLiveMatchNotification = onDocumentUpdated("LiveSignals/{signalId}", async (event) => {
    if (!event.data) return null;

    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();

    if (newValue.status === "ready_to_publish" && previousValue.status !== "ready_to_publish") {
        
        // Yeni 'send' metoduna uygun mesaj yapısı
        const message = {
            notification: {
                title: "🔥 CANLI TAHMİN GELDİ!",
                body: `${newValue.homeTeam} - ${newValue.awayTeam} maçı için yeni bir tahmin var.`
            },
            data: {
                matchID: newValue.id || event.params.signalId,
                homeTeam: newValue.homeTeam,
                awayTeam: newValue.awayTeam,
                prediction: newValue.prediction,
                minute: newValue.minute || "1'", // Firestore'dan gelen dakika bilgisini al
                type: "LIVE_SIGNAL"
            },
            topic: "all_users" // Topic artık mesajın içinde tanımlanıyor
        };

        try {
            // Eski sendToTopic yerine yeni 'send' metodu
            const response = await admin.messaging().send(message);
            console.log("✅ Bildirim başarıyla gönderildi:", response);

            return event.data.after.ref.update({ status: "published" });
        } catch (error) {
            console.error("❌ Bildirim gönderme hatası:", error);
        }
    }
    return null;
});