#include "VCDamage.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCCombatRules.h"
#include "VCGameplayTags.h"

namespace
{
	struct FVCDamageStatics
	{
		DECLARE_ATTRIBUTE_CAPTUREDEF(AttackPower);
		DECLARE_ATTRIBUTE_CAPTUREDEF(CritChance);
		DECLARE_ATTRIBUTE_CAPTUREDEF(CritMultiplier);
		DECLARE_ATTRIBUTE_CAPTUREDEF(Defense);
		DECLARE_ATTRIBUTE_CAPTUREDEF(BlockChance);
		DECLARE_ATTRIBUTE_CAPTUREDEF(BlockReduction);
		DECLARE_ATTRIBUTE_CAPTUREDEF(DodgeChance);

		FVCDamageStatics()
		{
			// Angreifer: Werte zum Zeitpunkt der Spec-Erstellung; Ziel: Werte beim Anwenden.
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, AttackPower, Source, true);
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, CritChance, Source, true);
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, CritMultiplier, Source, true);
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, Defense, Target, false);
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, BlockChance, Target, false);
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, BlockReduction, Target, false);
			DEFINE_ATTRIBUTE_CAPTUREDEF(UVCAttributeSet, DodgeChance, Target, false);
		}
	};

	const FVCDamageStatics& Statics()
	{
		static const FVCDamageStatics Instance;
		return Instance;
	}
}

UVCDamageExecution::UVCDamageExecution()
{
	RelevantAttributesToCapture.Add(Statics().AttackPowerDef);
	RelevantAttributesToCapture.Add(Statics().CritChanceDef);
	RelevantAttributesToCapture.Add(Statics().CritMultiplierDef);
	RelevantAttributesToCapture.Add(Statics().DefenseDef);
	RelevantAttributesToCapture.Add(Statics().BlockChanceDef);
	RelevantAttributesToCapture.Add(Statics().BlockReductionDef);
	RelevantAttributesToCapture.Add(Statics().DodgeChanceDef);
}

void UVCDamageExecution::Execute_Implementation(const FGameplayEffectCustomExecutionParameters& Params,
	FGameplayEffectCustomExecutionOutput& Out) const
{
	if (!FVCCombatData::IsAvailable())
	{
		return;
	}
	const FGameplayEffectSpec& Spec = Params.GetOwningSpec();
	FAggregatorEvaluateParameters Eval;
	Eval.SourceTags = Spec.CapturedSourceTags.GetAggregatedTags();
	Eval.TargetTags = Spec.CapturedTargetTags.GetAggregatedTags();

	auto Capture = [&Params, &Eval](const FGameplayEffectAttributeCaptureDefinition& Def)
	{
		float Value = 0.f;
		Params.AttemptCalculateCapturedAttributeMagnitude(Def, Eval, Value);
		return static_cast<double>(Value);
	};

	vc::rules::FCombatStats Attacker;
	Attacker.AttackPower = Capture(Statics().AttackPowerDef);
	Attacker.CritChance = Capture(Statics().CritChanceDef);
	Attacker.CritMultiplier = Capture(Statics().CritMultiplierDef);

	vc::rules::FCombatStats Defender;
	Defender.Defense = Capture(Statics().DefenseDef);
	Defender.BlockChance = Capture(Statics().BlockChanceDef);
	Defender.BlockReduction = Capture(Statics().BlockReductionDef);
	Defender.DodgeChance = Capture(Statics().DodgeChanceDef);

	const double WeaponDamage = Spec.GetSetByCallerMagnitude(TAG_VC_Data_WeaponDamage, false, 0.f);

	// Zufall nur hier auf dem Server; Clients rechnen nie Schaden aus.
	vc::rules::FAttackRolls Rolls;
	Rolls.Dodge = FMath::FRand();
	Rolls.Block = FMath::FRand();
	Rolls.Crit = FMath::FRand();
	Rolls.Variance = FMath::FRand();

	const vc::rules::FAttackOutcome Outcome =
		vc::rules::ResolveAttack(Attacker, Defender, WeaponDamage, Rolls, FVCCombatData::Tuning());
	if (Outcome.Damage > 0.0)
	{
		Out.AddOutputModifier(FGameplayModifierEvaluatedData(
			UVCAttributeSet::GetIncomingDamageAttribute(), EGameplayModOp::Additive, static_cast<float>(Outcome.Damage)));
	}
}

UVCDamageEffect::UVCDamageEffect()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;
	FGameplayEffectExecutionDefinition Execution;
	Execution.CalculationClass = UVCDamageExecution::StaticClass();
	Executions.Add(Execution);
}
