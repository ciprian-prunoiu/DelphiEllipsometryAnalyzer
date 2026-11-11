unit Physics.Ellipsometry;

interface

uses
  System.SysUtils,
  Domain.Types;

type
  TEllipsometryCalculator = class
  public
    class function Calculate(
      const AModel: TOpticalModel;
      const AWavelengthNm: Double): TMeasurement; static;
  end;

implementation

uses
  System.Math,
  Physics.Complex;

class function TEllipsometryCalculator.Calculate(
  const AModel: TOpticalModel;
  const AWavelengthNm: Double): TMeasurement;
var
  N0, N1, N2, CosTheta0, CosTheta1, CosTheta2, SinTheta0: TComplex;
  R01S, R12S, R01P, R12P, Phase, RS, RP, Rho: TComplex;
  Theta0, PhaseAngle: Double;
  One: TComplex;
begin
  if AWavelengthNm <= 0 then
    raise EArgumentOutOfRangeException.Create('Wavelength must be positive.');

  Theta0 := DegToRad(AModel.IncidenceAngleDeg);

  N0 := TComplex.Create(AModel.AmbientIndex);
  N1 := TComplex.Create(AModel.FilmIndex);
  N2 := TComplex.Create(AModel.SubstrateN, AModel.SubstrateK);

  CosTheta0 := TComplex.Create(Cos(Theta0));
  SinTheta0 := TComplex.Create(Sin(Theta0));
  One := TComplex.Create(1);

  CosTheta1 := One.Sub(
    N0.DivBy(N1).Mul(SinTheta0).Mul(N0.DivBy(N1).Mul(SinTheta0))).Sqrt;
  CosTheta2 := One.Sub(
    N0.DivBy(N2).Mul(SinTheta0).Mul(N0.DivBy(N2).Mul(SinTheta0))).Sqrt;

  R01S := N0.Mul(CosTheta0).Sub(N1.Mul(CosTheta1))
    .DivBy(N0.Mul(CosTheta0).Add(N1.Mul(CosTheta1)));
  R12S := N1.Mul(CosTheta1).Sub(N2.Mul(CosTheta2))
    .DivBy(N1.Mul(CosTheta1).Add(N2.Mul(CosTheta2)));
  R01P := N1.Mul(CosTheta0).Sub(N0.Mul(CosTheta1))
    .DivBy(N1.Mul(CosTheta0).Add(N0.Mul(CosTheta1)));
  R12P := N2.Mul(CosTheta1).Sub(N1.Mul(CosTheta2))
    .DivBy(N2.Mul(CosTheta1).Add(N1.Mul(CosTheta2)));

  PhaseAngle := 2 * Pi * AModel.FilmIndex * AModel.FilmThicknessNm
    * CosTheta1.Re / AWavelengthNm;
  Phase := ComplexExpI(2 * PhaseAngle);

  RS := R01S.Add(R12S.Mul(Phase))
    .DivBy(One.Add(R01S.Mul(R12S).Mul(Phase)));
  RP := R01P.Add(R12P.Mul(Phase))
    .DivBy(One.Add(R01P.Mul(R12P).Mul(Phase)));
  Rho := RP.DivBy(RS);

  Result.WavelengthNm := AWavelengthNm;
  Result.PsiDeg := RadToDeg(ArcTan(Rho.Abs));
  Result.DeltaDeg := Rho.ArgDegrees;
  if Result.DeltaDeg < 0 then
    Result.DeltaDeg := Result.DeltaDeg + 360;
end;

end.
