#pragma once

#include "CoreMinimal.h"
#include "VCHttp.h"

/**
 * Aufrufe des Zonen-Servers an die internen Backend-Endpunkte (mit Service-Key).
 * In Client-Builds (WITH_SERVER_CODE == 0) liefern alle Aufrufe sofort einen Fehler,
 * damit kein Codepfad mit Service-Key im Client existiert.
 */
class FVCServerBackend
{
public:
	/** true, wenn VC_SERVICE_KEY gesetzt ist. */
	static bool IsConfigured();

	static void ValidateTicket(const FString& Ticket, FVCHttpCallback Callback);
	static void LoadCharacter(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback);
	/**
	 * Position und (falls bekannt) Leben/Ausdauer speichern. Vitals mit MaxHealth <= 0 werden nicht mitgeschickt.
	 * Das Backend nimmt nur Speicherstände des Servers an, auf dem der Charakter ONLINE ist.
	 * bReleasePresence: letzter Stand beim Ausloggen, gibt die Anwesenheit in derselben Transaktion frei.
	 */
	static void SaveCharacter(int64 CharacterId, int64 AccountId, const FString& ZoneId,
		const FVector& Location, float Yaw, const FIntVector4& Vitals, bool bReleasePresence, FVCHttpCallback Callback);

	/** World Directory: Prozessstart melden (verwirft Anwesenheiten eines früheren Laufs). Antwort: heartbeatSeconds. */
	static void StartServer(const FString& Address, int32 Capacity, FVCHttpCallback Callback);
	/** Lebenszeichen. Kein Abmelden beim Beenden: ausstehende Speicherstände sollen nicht abgelehnt werden; der Timeout genügt. */
	static void Heartbeat(const FString& Address, int32 Capacity, FVCHttpCallback Callback);

	/** Charakter auf diesem Server ONLINE setzen. 409, wenn er anderswo online ist oder in einer anderen Zone steht. */
	static void ClaimCharacter(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback);
	/** Anwesenheit freigeben, wenn kein letzter Speicherstand folgt (z. B. Abbruch vor dem Spawn). */
	static void ReleaseCharacter(int64 CharacterId);

	/** Entdeckung melden. Antwort: firstTime, xpAwarded, progress (Belohnung legt das Backend fest). */
	static void ReportDiscovery(int64 CharacterId, int64 AccountId, const FString& DiscoveryCode, FVCHttpCallback Callback);

	/** Schiff beim Werftmeister kaufen; PurchaseKey macht Wiederholungen unschädlich. Antwort: duplicate, ship, gold. */
	static void BuyShip(int64 CharacterId, int64 AccountId, const FString& NpcCode, const FString& ShipCode, const FGuid& PurchaseKey,
		FVCHttpCallback Callback);
	static void SetActiveShip(int64 CharacterId, int64 AccountId, int64 InstanceId, FVCHttpCallback Callback);
	/** Rumpf, Besatzung, Proviant nach der Fahrt (können ohne Werft nur sinken). */
	static void SaveShip(int64 CharacterId, int64 AccountId, int64 InstanceId, int32 HullHp, int32 Crew, int32 Injured, int32 Provisions,
		FVCHttpCallback Callback);
	/** Hafendienst beim Werftmeister: REPAIR, HEAL, HIRE (Amount), PROVISIONS (Amount). Antwort: ship, gold, cost. */
	static void ShipService(int64 CharacterId, int64 AccountId, int64 InstanceId, const FString& NpcCode, const FString& Kind, int32 Amount,
		FVCHttpCallback Callback);
	/** Markt des Händlers: Waren mit Preisen der nächsten Einheit, eigene Ladung, Laderaum, Gold. */
	static void ViewMarket(int64 CharacterId, int64 AccountId, const FString& NpcCode, FVCHttpCallback Callback);
	/** Handel: Side BUY/SELL, Menge; Preis rechnet das Backend. Antwort: total, gold, stock, inCargo, cargoUsed, cargoCapacity. */
	static void Trade(int64 CharacterId, int64 AccountId, const FString& NpcCode, const FString& ItemCode, const FString& Side,
		int32 Quantity, FVCHttpCallback Callback);
	/** Admin: Gold gutschreiben; Rechte, Ledger und Audit prüft/schreibt das Backend in einer Transaktion. */
	static void AdminGrantGold(int64 CharacterId, int64 Amount, const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback);

	/** Zonenwechsel über einen Ausgang. Antwort: zoneId, address, arrivalTag. */
	static void RequestTransfer(int64 CharacterId, int64 AccountId, const FString& ExitCode, FVCHttpCallback Callback);
	static void WriteAdminAudit(const TSharedRef<FJsonObject>& Entry, FVCHttpCallback Callback);

	/** XP-Vergabe; jeder Aufruf bekommt einen neuen Idempotenzschlüssel. SkillCode leer = Charakter-XP. */
	static void GrantExperience(int64 CharacterId, int64 AccountId, const FString& SkillCode, int64 Amount,
		const FString& Source, FVCHttpCallback Callback);

	/** PvP-Regel und Art der Zone laden. */
	static void LoadZone(const FString& ZoneId, FVCHttpCallback Callback);

	/** Kill melden; das Backend vergibt XP aus den Gegnerdaten und führt die PvP-Statistik. */
	static void ReportKill(const TSharedRef<FJsonObject>& Kill, FVCHttpCallback Callback);

	/** Inventar (Plätze, Stapel, Ausrüstung). Antwort: capacity, items[]. */
	static void LoadInventory(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback);
	/** Action: equip, unequip (InstanceId), discard, sell (InstanceId, Quantity; sell mit NpcCode). Antwort: Inventar bzw. gold, total, inventory. */
	static void InventoryAction(int64 CharacterId, int64 AccountId, const FString& Action, int64 InstanceId, int32 Quantity,
		const FString& NpcCode, FVCHttpCallback Callback);
	/** Sammeln abgeschlossen. Antwort: itemCode, nameDe, quantity, lost, skill, inventory. */
	static void Gather(int64 CharacterId, int64 AccountId, const FString& NodeCode, FVCHttpCallback Callback);
	/** Rezepte mit Material im Inventar und ob es reicht. Antwort: Liste. */
	static void LoadRecipes(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback);
	/** Herstellen (alles oder nichts). Antwort wie Gather plus goldCost, gold. */
	static void Craft(int64 CharacterId, int64 AccountId, const FString& RecipeCode, int32 Times, FVCHttpCallback Callback);
	/** Auktionshaus. Action: search (Argument = Ware oder leer), mine, list, buy, cancel, collect. Antwort je Endpunkt. */
	static void Auction(int64 CharacterId, int64 AccountId, const FString& Action, const FString& NpcCode, int64 Id, int32 Quantity,
		int64 Price, const FString& ItemCode, FVCHttpCallback Callback);
	/** Chat senden (Prüfung, Stummschaltung, Rate-Limit, Protokoll). Antwort: messageId, channel, senderName, message, target…. */
	static void SendChat(int64 CharacterId, int64 AccountId, const FString& Channel, const FString& Message, const FString& TargetName,
		FVCHttpCallback Callback);
	/** Neue Nachrichten für diesen Server ab After (−1: nur Stand holen). Antwort: lastId, messages[]. */
	static void PollChat(int64 After, FVCHttpCallback Callback);
	/** Freundes-/Ignorierliste: Verb GET, POST (Name) oder DELETE (OtherId). List = "friends" oder "ignores". Antwort: Liste. */
	static void SocialList(int64 CharacterId, int64 AccountId, const FString& Verb, const FString& List, const FString& Name, int64 OtherId,
		FVCHttpCallback Callback);
	/**
	 * Gilden. Action: get, invites (GET); found (Name, Tag), invite/kick (Name), rank (Name, RankNo), leave, disband;
	 * accept/decline (GuildId). Antwort: Gildeninfo, Einladungsliste oder leer.
	 */
	static void Guild(int64 CharacterId, int64 AccountId, const FString& Action, const FString& Name, const FString& Tag, int32 RankNo,
		int64 GuildId, FVCHttpCallback Callback);
	/**
	 * Gildenkasse und Städte. Action: cities (GET, alle Städte), deposit/withdraw (Value = Gold), buycity (City),
	 * citytax (City, Value = Promille). Antwort: Städteliste bzw. Gildeninfo.
	 */
	static void GuildCity(int64 CharacterId, int64 AccountId, const FString& Action, const FString& City, int64 Value, FVCHttpCallback Callback);
	static void ReportPlayer(int64 CharacterId, int64 AccountId, const FString& Name, const FString& Reason, FVCHttpCallback Callback);
	/** Admin: stummschalten bzw. Systemmeldung; Rechte und Audit im Backend. */
	static void AdminMute(const FString& Name, int32 Minutes, const FString& Channel, const FString& Reason,
		const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback);
	static void AdminAnnounce(const FString& Message, const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback);
	/** Admin: Item ins Inventar; Rechte, Vergabe und Audit im Backend. Antwort: placed, lost, inventory. */
	static void AdminGrantItem(int64 CharacterId, const FString& ItemCode, int32 Quantity, const TSharedRef<FJsonObject>& AdminContext,
		FVCHttpCallback Callback);

	/** Ganze Hotbar ersetzen (Index = Platz, None = leer). Das Backend prüft Besitz, Plätze und Fähigkeiten. */
	static void SaveHotbar(int64 CharacterId, int64 AccountId, const TArray<FName>& Slots, FVCHttpCallback Callback);

	/** Admin: Level bzw. Skillstufe setzen. Das Backend prüft Rechte und schreibt Audit in derselben Transaktion. */
	static void AdminSetLevel(int64 CharacterId, const FString& SkillCode, int32 Level,
		const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback);
};
