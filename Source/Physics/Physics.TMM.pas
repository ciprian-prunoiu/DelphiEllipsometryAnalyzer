unit Physics.TMM;

/// <summary>
/// Transfer Matrix Method (TMM) calculator for ellipsometry.
/// Supports an arbitrary number of thin-film layers between an ambient
/// medium and a substrate. Implements the standard 2x2 characteristic
/// matrix formalism for s- and p-polarization, then derives Psi/Delta
/// from the complex reflection ratio Rho = Rp / Rs.
/// </summary>

interface

uses
  System.SysUtils, Domain.Types;

type
  /// <summary>
  /// Computes Psi and Delta for a given optical model and wavelength.
  /// </summary>
  TTransferMatrixCalculator = class
  public
    /// <summary>
    /// Evaluates Psi and Delta at a single wavelength.
    /// </summary>
    /// <param name="AModel">Optical model (ambient, layers, substrate).</param>
    /// <param name="AWavelengthNm">Wavelength in nanometers (must be > 0).</param>
    /// <returns>Psi (deg) and Delta (deg) with Delta normalized to [0, 360).</returns>
    class function Calculate(
      const AModel: TOpticalModel;
      const AWavelengthNm: Double): TMeasurement; static;
  end;

implementation

uses
  System.Math, Physics.Complex;

class function TTransferMatrixCalculator.Calculate(
  const AModel: TOpticalModel;
  const AWavelengthNm: Double): TMeasurement;
var
  Theta0, SinTheta0: Double;
  N_Amb, N_Sub, C_Amb, S_Amb: TComplex;
  i, NumLayers: Integer;

  // 2x2 characteristic matrix of the whole stack (starts as identity)
  M, M_Next, TempM: array[0..1, 0..1] of TComplex;

  // Per-layer temporaries
  L_N, L_CosTheta, L_Phase, L_CosPhase, L_SinPhase: TComplex;
  Thickness: Double;

  // Reflection coefficients and derived Psi/Delta
  Rs, Rp, Rho: TComplex;
  nI, nIcosI: TComplex;
begin
  // Sanity check on wavelength (avoid divide-by-zero downstream)
  if AWavelengthNm <= 0 then
    raise EArgumentException.Create('Invalid wavelength.');

  // Incidence angle (radians) and its sine
  Theta0 := DegToRad(AModel.IncidenceAngleDeg);
  SinTheta0 := Sin(Theta0);

  // Complex refractive indices of ambient and substrate
  N_Amb := TComplex.Create(AModel.AmbientN, 0);
  N_Sub := TComplex.Create(AModel.SubstrateN, AModel.SubstrateK);

  // Cosine and sine of the incidence angle (real, wrapped as complex)
  C_Amb := TComplex.Create(Cos(Theta0), 0);
  S_Amb := TComplex.Create(Sin(Theta0), 0);

  // Start with the identity matrix (no layers yet)
  M[0,0] := TComplex.Create(1); M[0,1] := TComplex.Create(0);
  M[1,0] := TComplex.Create(0); M[1,1] := TComplex.Create(1);

  NumLayers := Length(AModel.Layers);

  // Build the characteristic matrix by multiplying each layer's matrix
  for i := 0 to NumLayers - 1 do
  begin
    L_N := TComplex.Create(AModel.Layers[i].N, AModel.Layers[i].K);
    Thickness := AModel.Layers[i].ThicknessNm;

    // Snell's law in complex form: cos(theta) = sqrt(1 - (N0/N1 * sin(theta0))^2)
    L_CosTheta := TComplex.Create(1).Sub(
      N_Amb.DivBy(L_N).Mul(S_Amb).Mul(N_Amb.DivBy(L_N).Mul(S_Amb))).Sqrt;

    // Optical phase thickness: delta = 2*pi*N*d*cos(theta) / lambda
    L_Phase := L_N.Mul(L_CosTheta).Mul(
      TComplex.Create(2 * Pi * Thickness / AWavelengthNm));

    // Complex trig functions (needed for absorbing layers, K > 0)
    L_CosPhase := ComplexCos(L_Phase);
    L_SinPhase := ComplexSin(L_Phase);

    // Characteristic matrix of a single layer
    M_Next[0,0] := L_CosPhase;
    M_Next[0,1] := L_SinPhase.DivBy(L_N.Mul(L_CosTheta)).Mul(TComplex.Create(0, -1));
    M_Next[1,0] := L_SinPhase.Mul(L_N.Mul(L_CosTheta)).Mul(TComplex.Create(0, 1));
    M_Next[1,1] := L_CosPhase;

    // Multiply M = M * M_Next (using a temporary matrix)
    TempM[0,0] := M[0,0].Mul(M_Next[0,0]).Add(M[0,1].Mul(M_Next[1,0]));
    TempM[0,1] := M[0,0].Mul(M_Next[0,1]).Add(M[0,1].Mul(M_Next[1,1]));
    TempM[1,0] := M[1,0].Mul(M_Next[0,0]).Add(M[1,1].Mul(M_Next[1,0]));
    TempM[1,1] := M[1,0].Mul(M_Next[0,1]).Add(M[1,1].Mul(M_Next[1,1]));
    M := TempM;
  end;

  // Optical admittance of the ambient: n0 * cos(theta0)
  nI := N_Amb.Mul(C_Amb);

  // Optical admittance of the substrate: n_sub * cos(theta_sub)
  nIcosI := N_Sub.Mul(
    TComplex.Create(1).Sub(
      N_Amb.DivBy(N_Sub).Mul(S_Amb).Mul(N_Amb.DivBy(N_Sub).Mul(S_Amb))).Sqrt);

  // s-polarization reflection coefficient
  Rs := (nI.Mul(M[0,0])
    .Add(nI.Mul(nIcosI).Mul(M[0,1]))
    .Sub(M[1,0])
    .Sub(nIcosI.Mul(M[1,1])))
    .DivBy(
    nI.Mul(M[0,0])
    .Add(nI.Mul(nIcosI).Mul(M[0,1]))
    .Add(M[1,0])
    .Add(nIcosI.Mul(M[1,1])));

  // p-polarization reflection coefficient
  Rp := (nIcosI.Mul(M[0,0])
    .Add(nI.Mul(nIcosI).Mul(nIcosI).Mul(M[0,1]))
    .Sub(M[1,0])
    .Sub(nI.Mul(M[1,1])))
    .DivBy(
    nIcosI.Mul(M[0,0])
    .Add(nI.Mul(nIcosI).Mul(nIcosI).Mul(M[0,1]))
    .Add(M[1,0])
    .Add(nI.Mul(M[1,1])));

  // Complex reflection ratio
  Rho := Rp.DivBy(Rs);

  // Psi = arctan(|Rho|), Delta = arg(Rho), normalized to [0, 360)
  Result.WavelengthNm := AWavelengthNm;
  Result.PsiDeg := RadToDeg(ArcTan(Rho.Abs));
  Result.DeltaDeg := Rho.ArgDegrees;
  if Result.DeltaDeg < 0 then
    Result.DeltaDeg := Result.DeltaDeg + 360;
end;

end.
