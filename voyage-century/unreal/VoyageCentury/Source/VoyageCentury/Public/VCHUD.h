#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "VCAbilityStateComponent.h"
#include "VCCombatStateComponent.h"
#include "VCHUD.generated.h"

/**
 * Einfaches Kampf-HUD ohne Assets (Canvas): eigene Leben/Ausdauer und Statuseffekte, Zielrahmen,
 * Hotbar mit Abklingzeiten, Kampftexte über den Köpfen, Hinweise (abgelehnte Fähigkeit, Entdeckung) und
 * das Fenster eines angesprochenen NPCs.
 * Platzhalter, bis das UI nach der Screenshot-Analyse mit UMG gebaut wird (siehe GDD, UI).
 * Zeigt nur an, was der Server repliziert; nichts davon ist spielentscheidend.
 */
UCLASS()
class VOYAGECENTURY_API AVCHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void DrawHUD() override;

private:
	struct FFloatingText
	{
		TWeakObjectPtr<AActor> Actor;
		FString Text;
		FLinearColor Color;
		double StartTime = 0.0;
	};

	TArray<FFloatingText> FloatingTexts;
	FString Notice;
	double NoticeUntil = 0.0;
	FDelegateHandle CombatTextHandle;
	FDelegateHandle BlockedHandle;
	FDelegateHandle ShipHitHandle;
	TWeakObjectPtr<UVCAbilityStateComponent> BoundAbilityState;
	bool bBoundController = false;
	FName DialogNpc;
	double DialogUntil = 0.0;

	void OnCombatText(AActor* Target, EVCCombatText Kind, int32 Amount);
	void OnAbilityBlocked(FName Code, EVCAbilityBlock Reason);
	void OnNpcDialog(FName NpcCode);
	void OnShipHit(class AVCShip* Ship, int32 Hits, int32 HullDamage, int32 CrewLosses);
	void OnDiscovered(FName DiscoveryCode, int64 XpAwarded);
	void DrawNpcDialog();
	/** Am Steuer eines Schiffs: Fahrt, Kurs, Segel, Ruder, Wind, Rumpf, Matrosen, Proviant. */
	void DrawShipPanel();

	double LocalNow() const;
	double ServerNow() const;
	void DrawBar(float X, float Y, float Width, float Height, double Value, double Max, const FLinearColor& Color, const FString& Label);
	void DrawStatuses(float X, float Y, const UVCCombatStateComponent* State);
	void DrawOwnFrame();
	void DrawTargetFrame();
	void DrawHotbar();
	void DrawFloatingTexts();
	void DrawNotice();
};
