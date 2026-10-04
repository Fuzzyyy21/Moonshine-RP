#include "VCPlayerState.h"
#include "VCProgressionComponent.h"

AVCPlayerState::AVCPlayerState()
{
	Progression = CreateDefaultSubobject<UVCProgressionComponent>(TEXT("Progression"));
}
