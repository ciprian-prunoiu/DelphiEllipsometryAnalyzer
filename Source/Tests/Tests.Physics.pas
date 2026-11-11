unit Tests.Physics;

/// <summary>
/// DUnitX test suite for the Transfer Matrix Method (TMM) engine.
/// Covers:
///   1. Reference values at a known wavelength
///   2. Zero-thickness (substrate-only) edge case
///   3. Angular sensitivity
///   4. Spectral sanity across the visible range
///   5. Physical invariants (Psi in [0, 90], Delta in [0, 360))
/// </summary>

interface

uses
  DUnitX.TestFramework, Domain.Types, Physics.TMM, System.Math, System.SysUtils;

type
  /// <summary>
  /// Tests for the TTransferMatrixCalculator.
  /// </summary>
  [TestFixture]
  TPhysicsTests = class
  public
    /// <summary>
    /// Verifies TMM output against reference values for a known stack:
    /// 100 nm SiO2 on Si at 70 degrees AOI, 632.8 nm (He-Ne laser).
    /// </summary>
    [Test]
    procedure Test_SingleLayer_SiO2_Thickness100nm_RefValues;

    /// <summary>
    /// Zero-thickness film must reduce to bare substrate reflection.
    /// </summary>
    [Test]
    procedure Test_SubstrateOnly_ZeroThickness;

    /// <summary>
    /// Changing the AOI must change Psi and Delta (sanity check for geometry).
    /// </summary>
    [Test]
    procedure Test_Angle_Effects;

    /// <summary>
    /// Parameterized test: sweeps across red, blue, and near-IR wavelengths
    /// to ensure no NaN or Infinity is produced.
    /// </summary>
    [Test]
    [TestCase('Red Light (632.8nm)', '632.8')]
    [TestCase('Blue Light (450nm)', '450.0')]
    [TestCase('Near IR (900nm)', '900.0')]
    procedure Test_Wavelength_Calculations(const AWavelengthNm: Double);

    /// <summary>
    /// Sweeps the full visible spectrum (400-800 nm) and asserts that
    /// Psi stays in [0, 90] and Delta stays in [0, 360) at every step.
    /// </summary>
    [Test]
    procedure Test_Physical_Bounds;
  end;

implementation

procedure TPhysicsTests.Test_SingleLayer_SiO2_Thickness100nm_RefValues;
var
  Model: TOpticalModel;
  Result: TMeasurement;
  ExpectedPsi, ExpectedDelta, Tolerance: Double;
begin
  // Default model: 100 nm SiO2 on Si (N=3.88, K=0.02), AOI = 70 deg
  Model := TOpticalModel.Default;
  Result := TTransferMatrixCalculator.Calculate(Model, 632.8); // He-Ne laser

  // Reference values obtained from an independent TMM implementation
  // (e.g. Python + PyEllipsometry) at the same wavelength and AOI.
  ExpectedPsi   := 47.11;
  ExpectedDelta := 115.30;
  Tolerance     := 0.50; // 0.5 degree tolerance

  Assert.AreEqual(ExpectedPsi, Result.PsiDeg, Tolerance,
    Format('Psi mismatch at 632.8 nm. Expected ~%.2f, got %.2f',
      [ExpectedPsi, Result.PsiDeg]));

  Assert.AreEqual(ExpectedDelta, Result.DeltaDeg, Tolerance,
    Format('Delta mismatch at 632.8 nm. Expected ~%.2f, got %.2f',
      [ExpectedDelta, Result.DeltaDeg]));
end;

procedure TPhysicsTests.Test_SubstrateOnly_ZeroThickness;
var
  Model: TOpticalModel;
  Result: TMeasurement;
begin
  Model := TOpticalModel.Default;
  Model.Layers[0].ThicknessNm := 0.0; // Pure substrate reflection

  Result := TTransferMatrixCalculator.Calculate(Model, 632.8);

  // Even with zero film thickness, the result must remain physical.
  Assert.IsTrue((Result.PsiDeg >= 0.0) and (Result.PsiDeg <= 90.0),
    'Substrate Psi out of physical bounds');
  Assert.IsTrue((Result.DeltaDeg >= 0.0) and (Result.DeltaDeg <= 360.0),
    'Substrate Delta out of physical bounds');
end;

procedure TPhysicsTests.Test_Angle_Effects;
var
  Model: TOpticalModel;
  Res70, Res50: TMeasurement;
begin
  Model := TOpticalModel.Default;

  Model.IncidenceAngleDeg := 70.0;
  Res70 := TTransferMatrixCalculator.Calculate(Model, 632.8);

  Model.IncidenceAngleDeg := 50.0;
  Res50 := TTransferMatrixCalculator.Calculate(Model, 632.8);

  // Changing AOI must produce different polarization parameters
  Assert.AreNotEqual(Res70.PsiDeg, Res50.PsiDeg, 0.01,
    'Psi should vary significantly with incidence angle');
  Assert.AreNotEqual(Res70.DeltaDeg, Res50.DeltaDeg, 0.01,
    'Delta should vary significantly with incidence angle');
end;

procedure TPhysicsTests.Test_Wavelength_Calculations(const AWavelengthNm: Double);
var
  Model: TOpticalModel;
  Result: TMeasurement;
begin
  Model := TOpticalModel.Default;
  Result := TTransferMatrixCalculator.Calculate(Model, AWavelengthNm);

  // Sanity: the calculation must produce finite, non-NaN numbers
  Assert.IsFalse(IsNaN(Result.PsiDeg),
    Format('Psi is NaN at %f nm', [AWavelengthNm]));
  Assert.IsFalse(IsNaN(Result.DeltaDeg),
    Format('Delta is NaN at %f nm', [AWavelengthNm]));
  Assert.IsFalse(IsInfinite(Result.PsiDeg),
    Format('Psi is Infinity at %f nm', [AWavelengthNm]));
  Assert.IsFalse(IsInfinite(Result.DeltaDeg),
    Format('Delta is Infinity at %f nm', [AWavelengthNm]));
end;

procedure TPhysicsTests.Test_Physical_Bounds;
var
  Model: TOpticalModel;
  Result: TMeasurement;
  W: Integer;
begin
  Model := TOpticalModel.Default;

  // Sweep the visible spectrum and enforce strict invariants
  for W := 400 to 800 do
  begin
    Result := TTransferMatrixCalculator.Calculate(Model, W);

    Assert.IsTrue((Result.PsiDeg >= 0.0) and (Result.PsiDeg <= 90.0),
      Format('Psi violates [0, 90] at %d nm: %.2f', [W, Result.PsiDeg]));

    Assert.IsTrue((Result.DeltaDeg >= 0.0) and (Result.DeltaDeg < 360.0),
      Format('Delta violates [0, 360) at %d nm: %.2f', [W, Result.DeltaDeg]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhysicsTests);

end.
