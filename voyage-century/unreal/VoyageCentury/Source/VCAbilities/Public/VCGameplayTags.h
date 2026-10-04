#pragma once

#include "NativeGameplayTags.h"

// Native Gameplay Tags (keine Einträge in DefaultGameplayTags.ini nötig).

/** Ereignis: Grundangriff auf das Ziel im Event-Payload. */
VCABILITIES_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_VC_Event_Attack);

/** Zustand: tot. Blockiert alle Fähigkeiten. */
VCABILITIES_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_VC_State_Dead);

/** SetByCaller: Waffenschaden inklusive Skillbonus. */
VCABILITIES_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_VC_Data_WeaponDamage);
