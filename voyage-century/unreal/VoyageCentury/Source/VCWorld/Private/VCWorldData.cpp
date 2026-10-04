#include "VCWorldData.h"
#include "Engine/DataTable.h"

namespace
{
	UDataTable* Load(const TSoftObjectPtr<UDataTable>& Ref)
	{
		UDataTable* Table = Ref.IsNull() ? nullptr : Ref.LoadSynchronous();
		if (Table && !Table->IsRooted())
		{
			Table->AddToRoot(); // Konfigurationsdaten: für die Laufzeit des Prozesses geladen halten
		}
		return Table;
	}

	UDataTable* Npcs()
	{
		static UDataTable* Table = Load(GetDefault<UVCWorldSettings>()->NpcsTable);
		return Table;
	}

	UDataTable* Discoveries()
	{
		static UDataTable* Table = Load(GetDefault<UVCWorldSettings>()->DiscoveriesTable);
		return Table;
	}
}

const FVCNpcRow* FVCWorldData::FindNpc(FName Code)
{
	UDataTable* Table = Npcs();
	return Table && !Code.IsNone() ? Table->FindRow<FVCNpcRow>(Code, TEXT("VCWorldData"), false) : nullptr;
}

const FVCDiscoveryRow* FVCWorldData::FindDiscovery(FName Code)
{
	UDataTable* Table = Discoveries();
	return Table && !Code.IsNone() ? Table->FindRow<FVCDiscoveryRow>(Code, TEXT("VCWorldData"), false) : nullptr;
}

FString FVCWorldData::NpcDisplayName(FName Code)
{
	const FVCNpcRow* Row = FindNpc(Code);
	if (!Row)
	{
		return Code.ToString();
	}
	return !Row->NameDe.IsEmpty() ? Row->NameDe : !Row->NameZh.IsEmpty() ? Row->NameZh : Code.ToString();
}
