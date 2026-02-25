import { onValueCreated } from "firebase-functions/v2/database";
import { initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

// ✅ Veritabanı URL'ini ve Bölgeyi (europe-west1) açıkça belirtiyoruz
export const sendMatchNotification = onValueCreated({
    ref: "/matches/{date}/{matchId}",
    instance: "overorunder-7943d-default-rtdb", // Veritabanı ismin
    region: "europe-west1" // 👈 Belçika bölgesi
}, async (event) => {
    const matchData = event.data.val();

    if (!matchData || !matchData.sendPush) {
        console.log("Bildirim gönderimi kapalı veya veri bulunamadı.");
        return;
    }

    const homeTeam = matchData.homeTeam || "Bilinmeyen Takım";
    const awayTeam = matchData.awayTeam || "Bilinmeyen Takım";
    const guess = matchData.guess || "Yeni Analiz";

    const message = {
        notification: {
            title: "Yeni Analiz Eklendi! ⚽️",
            body: `${homeTeam} - ${awayTeam} maçı için ${guess} tahmini hazır. Hemen göz at!`,
        },
        topic: "all_users",
    };

    try {
        const response = await getMessaging().send(message);
        console.log("✅ Bildirim başarıyla gönderildi:", response);
    } catch (error) {
        console.error("❌ Bildirim gönderilirken hata oluştu:", error);
    }
});