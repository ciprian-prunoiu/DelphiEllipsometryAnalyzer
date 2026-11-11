unit Services.Simulator;

/// <summary>
/// Synthetic measurement simulator.
/// Generates Psi/Delta spectra from an optical model using the TMM engine.
/// Adds realistic noise to emulate real instrument measurements.
/// </summary>

interface

uses
  System.SysUtils,
  Domain.Types;

type
  /// <summary>
  /// Generates synthetic ellipsometric measurements (Psi/Delta vs. wavelength).
  /// </summary>
  TMeasurementSimulator = class
  public
    /// <summary>
    /// Generates an array of measurements for the given optical model.
    /// </summary>
    /// <param name="AModel">The optical model (layers, substrate, angle).</param>
    /// <param name="AStartNm">Start wavelength in nanometers.</param>
    /// <param name="AEndNm">End wavelength in nanometers.</param>
    /// <param name="ACount">Number of spectral points to generate.</param>
    /// <param name="ANoiseDeg">Noise amplitude in degrees (default: 0.015°).</param>
    /// <returns>Array of TMeasurement records.</returns>
    class function Generate(
      const AModel: TOpticalModel;
      const AStartNm, AEndNm: Double;
      const ACount: Integer;
      const ANoiseDeg: Double = 0.015): TMeasurementArray; static;
  end;

implementation

uses
  System.Math,
  Physics.TMM;

class function TMeasurementSimulator.Generate(
  const AModel: TOpticalModel;
  const AStartNm, AEndNm: Double;
  const ACount: Integer;
  const ANoiseDeg: Double): TMeasurementArray;
var
  I: Integer;
  Wavelength, Step: Double;
begin
  // Validate input parameters
  if ACount < 2 then
    raise EArgumentOutOfRangeException.Create('At least two samples are required.');
  if AEndNm <= AStartNm then
    raise EArgumentException.Create('Invalid wavelength range.');

  // Initialize random number generator for noise
  Randomize;

  // Allocate result array
  SetLength(Result, ACount);
  Step := (AEndNm - AStartNm) / (ACount - 1);

  // Generate one measurement per wavelength
  for I := 0 to ACount - 1 do
  begin
    Wavelength := AStartNm + I * Step;

    // Compute theoretical Psi/Delta using the Transfer Matrix Method
    Result[I] := TTransferMatrixCalculator.Calculate(AModel, Wavelength);

    // Add random noise to emulate real instrument measurement
    // Psi noise is small (ANoiseDeg), Delta noise is larger (ANoiseDeg * 8)
    // because Delta is more sensitive to phase errors in real ellipsometers
    Result[I].PsiDeg := Result[I].PsiDeg + (Random * 2 - 1) * ANoiseDeg;
    Result[I].DeltaDeg := Result[I].DeltaDeg + (Random * 2 - 1) * ANoiseDeg * 8;
  end;
end;

end.
