unit Physics.Complex;

/// <summary>
/// Complex number arithmetic used throughout the optical simulations.
/// Implemented as a value-type record for zero heap allocation and
/// deterministic memory behaviour in tight numerical loops.
/// </summary>

interface

uses
  System.Math;

type
  /// <summary>
  /// Lightweight complex number (Re + Im*i).
  /// All operations return new records; no mutation is performed in-place.
  /// </summary>
  TComplex = record
    Re: Double;
    Im: Double;

    /// <summary>
    /// Constructs a complex number from real and imaginary parts.
    /// </summary>
    class function Create(const ARe: Double; const AIm: Double = 0): TComplex; static;

    /// <summary>Adds two complex numbers.</summary>
    function Add(const B: TComplex): TComplex;

    /// <summary>Subtracts B from the current complex number.</summary>
    function Sub(const B: TComplex): TComplex;

    /// <summary>Multiplies two complex numbers using the standard (a+bi)(c+di) formula.</summary>
    function Mul(const B: TComplex): TComplex;

    /// <summary>
    /// Divides the current number by B. Returns 0 if B is effectively zero
    /// (denominator below 1e-30) to avoid division-by-zero in numerical loops.
    /// </summary>
    function DivBy(const B: TComplex): TComplex;

    /// <summary>
    /// Principal square root of a complex number.
    /// Uses the standard half-angle formula, with sign correction for negative
    /// imaginary parts to return the branch with matching sign.
    /// </summary>
    function Sqrt: TComplex;

    /// <summary>Magnitude (modulus) of the complex number.</summary>
    function Abs: Double;

    /// <summary>Argument (phase angle) in degrees, in the range (-180, 180].</summary>
    function ArgDegrees: Double;
  end;

/// <summary>
/// Returns e^(i*A) = cos(A) + i*sin(A) for a real angle A.
/// Used to apply the optical phase thickness of a film.
/// </summary>
function ComplexExpI(const A: Double): TComplex;

/// <summary>
/// Complex cosine: cos(x + iy) = cos(x)*cosh(y) - i*sin(x)*sinh(y).
/// Required because film phase thicknesses are complex when the layer
/// has absorption (K > 0) or when Snell's law produces a complex angle.
/// </summary>
function ComplexCos(const Z: TComplex): TComplex;

/// <summary>
/// Complex sine: sin(x + iy) = sin(x)*cosh(y) + i*cos(x)*sinh(y).
/// </summary>
function ComplexSin(const Z: TComplex): TComplex;

implementation

class function TComplex.Create(const ARe: Double; const AIm: Double): TComplex;
begin
  Result.Re := ARe;
  Result.Im := AIm;
end;

function TComplex.Add(const B: TComplex): TComplex;
begin
  Result := TComplex.Create(Re + B.Re, Im + B.Im);
end;

function TComplex.Sub(const B: TComplex): TComplex;
begin
  Result := TComplex.Create(Re - B.Re, Im - B.Im);
end;

function TComplex.Mul(const B: TComplex): TComplex;
begin
  // (a+bi)(c+di) = (ac - bd) + (ad + bc)i
  Result := TComplex.Create(
    Re * B.Re - Im * B.Im,
    Re * B.Im + Im * B.Re);
end;

function TComplex.DivBy(const B: TComplex): TComplex;
var
  Denom: Double;
begin
  // |B|^2 = c^2 + d^2
  Denom := B.Re * B.Re + B.Im * B.Im;

  // Guard against division by zero (avoid NaN propagation in fits)
  if Denom < 1E-30 then
    Exit(TComplex.Create(0));

  // (a+bi)/(c+di) = ((ac+bd) + (bc-ad)i) / (c^2+d^2)
  Result := TComplex.Create(
    (Re * B.Re + Im * B.Im) / Denom,
    (Im * B.Re - Re * B.Im) / Denom);
end;

function TComplex.Sqrt: TComplex;
var
  R, X, Y: Double;
begin
  // Magnitude of the input
  R := Hypot(Re, Im);

  // Real and imaginary parts of the principal square root
  X := System.Sqrt(Max(0, (R + Re) / 2));
  Y := System.Sqrt(Max(0, (R - Re) / 2));

  // Preserve the sign of the imaginary part (principal branch)
  if Im < 0 then
    Y := -Y;

  Result := TComplex.Create(X, Y);
end;

function TComplex.Abs: Double;
begin
  Result := Hypot(Re, Im);
end;

function TComplex.ArgDegrees: Double;
begin
  // ArcTan2 handles all four quadrants correctly
  Result := RadToDeg(ArcTan2(Im, Re));
end;

function ComplexExpI(const A: Double): TComplex;
begin
  // Euler's formula: e^(iA) = cos(A) + i*sin(A)
  Result := TComplex.Create(Cos(A), Sin(A));
end;

function ComplexCos(const Z: TComplex): TComplex;
begin
  // cos(x + iy) = cos(x)cosh(y) - i sin(x)sinh(y)
  Result := TComplex.Create(Cos(Z.Re) * Cosh(Z.Im), -Sin(Z.Re) * Sinh(Z.Im));
end;

function ComplexSin(const Z: TComplex): TComplex;
begin
  // sin(x + iy) = sin(x)cosh(y) + i cos(x)sinh(y)
  Result := TComplex.Create(Sin(Z.Re) * Cosh(Z.Im), Cos(Z.Re) * Sinh(Z.Im));
end;

end.
