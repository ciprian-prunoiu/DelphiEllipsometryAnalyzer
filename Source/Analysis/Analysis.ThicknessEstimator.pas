unit Analysis.ThicknessEstimator;

/// <summary>
/// Optical thickness estimation engine.
/// Provides two fitting strategies:
///   1. EstimateSingle: grid search + local refinement (fast, robust for one film)
///   2. EstimateMulti:  Nelder-Mead Simplex (general-purpose, supports N films)
/// Both strategies minimize a weighted sum of squared errors between
/// measured and calculated Psi/Delta spectra.
/// </summary>

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, Domain.Types;

type
  /// <summary>
  /// Result of a multi-layer fitting operation.
  /// </summary>
  TThicknessFitResult = record
    /// <summary>Estimated thicknesses for each fitted layer (nm).</summary>
    FittedThicknesses: TArray<Double>;
    /// <summary>Weighted sum of squared errors at the optimum.</summary>
    SumSquaredError: Double;
    /// <summary>Root-mean-square error per data point (Psi and Delta combined).</summary>
    RMSError: Double;
    /// <summary>Number of spectral points used in the fit.</summary>
    SampleCount: Integer;
  end;

  /// <summary>
  /// Static fitting engine for optical thickness estimation.
  /// </summary>
  TThicknessEstimator = class
  private
    /// <summary>
    /// Computes the weighted sum of squared errors for a given set of thicknesses.
    /// Psi residuals are weighted 1:1, Delta residuals are divided by 100
    /// to account for their larger numerical range (0..360 vs 0..90).
    /// </summary>
    class function CalculateError(const AMeasured: TMeasurementArray;
      const ABaseModel: TOpticalModel;
      const AThicknesses: TArray<Double>): Double; static;
  public
    /// <summary>
    /// Estimates the thickness of the FIRST layer using a coarse grid search
    /// followed by a local refinement pass.
    /// </summary>
    /// <param name="AMeasured">Measured Psi/Delta spectrum.</param>
    /// <param name="ABaseModel">Optical model (only the first layer's thickness is varied).</param>
    /// <param name="AThickMinNm">Minimum thickness to search.</param>
    /// <param name="AThickMaxNm">Maximum thickness to search.</param>
    /// <param name="ACoarseSteps">Number of grid points in the coarse pass.</param>
    /// <returns>The estimated thickness in nm.</returns>
    class function EstimateSingle(const AMeasured: TMeasurementArray;
      const ABaseModel: TOpticalModel;
      const AThickMinNm, AThickMaxNm: Double;
      const ACoarseSteps: Integer = 300): Double; static;

    /// <summary>
    /// Estimates the thicknesses of ALL layers simultaneously using the
    /// Nelder-Mead Simplex algorithm. Requires an initial guess.
    /// </summary>
    /// <param name="AMeasured">Measured Psi/Delta spectrum.</param>
    /// <param name="ABaseModel">Optical model.</param>
    /// <param name="AInitialGuess">Initial thickness for each layer (nm).</param>
    /// <param name="AMaxIterations">Maximum number of simplex iterations.</param>
    class function EstimateMulti(const AMeasured: TMeasurementArray;
      const ABaseModel: TOpticalModel;
      const AInitialGuess: TArray<Double>;
      const AMaxIterations: Integer = 500): TThicknessFitResult; static;
  end;

implementation

uses
  Physics.TMM;

/// <summary>
/// Returns the shortest angular difference between A and B, in (-180, 180].
/// Prevents artificial discontinuities when Delta wraps around 0/360.
/// </summary>
function WrappedAngleDifference(const A, B: Double): Double;
begin
  Result := A - B;
  while Result > 180 do Result := Result - 360;
  while Result < -180 do Result := Result + 360;
end;

class function TThicknessEstimator.CalculateError(
  const AMeasured: TMeasurementArray;
  const ABaseModel: TOpticalModel;
  const AThicknesses: TArray<Double>): Double;
var
  I, LayerIdx: Integer;
  TrialModel: TOpticalModel;
  Calc: TMeasurement;
  PsiErr, DeltaErr: Double;
begin
  // Clone the base model so we can mutate the trial thicknesses safely.
  // Important: dynamic arrays are reference-counted in Delphi, so we must
  // explicitly Copy() them before writing to avoid changing the caller's model.
  TrialModel := ABaseModel;
  TrialModel.Layers := Copy(ABaseModel.Layers);

  // Apply the candidate thicknesses (LayerIdx 0 = first layer, etc.)
  for LayerIdx := 0 to High(AThicknesses) do
  begin
    if LayerIdx <= High(TrialModel.Layers) then
      TrialModel.Layers[LayerIdx].ThicknessNm := AThicknesses[LayerIdx];
  end;

  // Accumulate weighted squared errors
  Result := 0;
  for I := 0 to High(AMeasured) do
  begin
    Calc := TTransferMatrixCalculator.Calculate(TrialModel, AMeasured[I].WavelengthNm);

    PsiErr := Calc.PsiDeg - AMeasured[I].PsiDeg;
    DeltaErr := WrappedAngleDifference(Calc.DeltaDeg, AMeasured[I].DeltaDeg);

    // Delta is divided by 100 to balance its contribution with Psi
    Result := Result + Sqr(PsiErr) + Sqr(DeltaErr) / 100.0;
  end;
end;

class function TThicknessEstimator.EstimateSingle(
  const AMeasured: TMeasurementArray;
  const ABaseModel: TOpticalModel;
  const AThickMinNm, AThickMaxNm: Double;
  const ACoarseSteps: Integer): Double;
var
  I: Integer;
  Thickness, Step, BestThickness, Err, BestErr: Double;
  Params: TArray<Double>;
begin
  if Length(ABaseModel.Layers) = 0 then
    raise EArgumentException.Create('No layers.');

  BestThickness := AThickMinNm;
  BestErr := MaxDouble;
  Step := (AThickMaxNm - AThickMinNm) / ACoarseSteps;

  // Phase 1: coarse grid search across the full thickness range
  for I := 0 to ACoarseSteps do
  begin
    Thickness := AThickMinNm + I * Step;
    Params := [Thickness];
    Err := CalculateError(AMeasured, ABaseModel, Params);
    if Err < BestErr then
    begin
      BestErr := Err;
      BestThickness := Thickness;
    end;
  end;

  // Phase 2: fine local refinement around the best coarse point
  Step := Step / 20;
  for I := -20 to 20 do
  begin
    Thickness := EnsureRange(BestThickness + I * Step, AThickMinNm, AThickMaxNm);
    Params := [Thickness];
    Err := CalculateError(AMeasured, ABaseModel, Params);
    if Err < BestErr then
    begin
      BestErr := Err;
      BestThickness := Thickness;
    end;
  end;

  Result := BestThickness;
end;

class function TThicknessEstimator.EstimateMulti(
  const AMeasured: TMeasurementArray;
  const ABaseModel: TOpticalModel;
  const AInitialGuess: TArray<Double>;
  const AMaxIterations: Integer): TThicknessFitResult;
var
  N, I, J, Iter: Integer;

  // Simplex: N+1 points in N-dimensional space, each with an associated error
  Simplex: TArray<TArray<Double>>;
  Errors: TArray<Double>;

  // Working vectors for reflection/expansion/contraction/shrink
  Centroid, Reflected, Expanded, Contracted: TArray<Double>;

  ErrReflected, ErrExpanded, ErrContracted, ErrWorst, ErrBest: Double;
  Alpha, Gamma, Rho, Sigma: Double;
  TempParams: TArray<Double>;
begin
  N := Length(AInitialGuess);
  if N = 0 then
    raise EArgumentException.Create('Initial guess cannot be empty.');

  // Standard Nelder-Mead coefficients
  Alpha := 1.0;  // Reflection
  Gamma := 2.0;  // Expansion
  Rho   := 0.5;  // Contraction
  Sigma := 0.5;  // Shrink

  // Initialize the simplex with N+1 points around the initial guess
  SetLength(Simplex, N + 1);
  SetLength(Errors, N + 1);

  Simplex[0] := Copy(AInitialGuess);
  for I := 1 to N do
  begin
    Simplex[I] := Copy(AInitialGuess);
    Simplex[I][I - 1] := Simplex[I][I - 1] + 10.0; // 10 nm offset per dimension
  end;

  // Evaluate initial errors
  for I := 0 to N do
    Errors[I] := CalculateError(AMeasured, ABaseModel, Simplex[I]);

  for Iter := 1 to AMaxIterations do
  begin
    // 1. Sort the simplex so that Errors[0] is the best and Errors[N] is the worst
    for I := 0 to N - 1 do
      for J := I + 1 to N do
        if Errors[J] < Errors[I] then
        begin
          TempParams := Simplex[I];
          Simplex[I] := Simplex[J];
          Simplex[J] := TempParams;

          ErrBest := Errors[I];
          Errors[I] := Errors[J];
          Errors[J] := ErrBest;
        end;

    ErrBest  := Errors[0];
    ErrWorst := Errors[N];

    // 2. Convergence: if the spread is tiny, we are done
    if Abs(ErrWorst - ErrBest) < 1E-6 then Break;

    // 3. Compute the centroid of the best N points (all except the worst)
    SetLength(Centroid, N);
    for I := 0 to N - 1 do
    begin
      Centroid[I] := 0;
      for J := 0 to N - 1 do
        Centroid[I] := Centroid[I] + Simplex[J][I];
      Centroid[I] := Centroid[I] / N;
    end;

    // 4. Reflection: mirror the worst point through the centroid
    SetLength(Reflected, N);
    for I := 0 to N - 1 do
      Reflected[I] := Centroid[I] + Alpha * (Centroid[I] - Simplex[N][I]);
    ErrReflected := CalculateError(AMeasured, ABaseModel, Reflected);

    if ErrReflected < ErrBest then
    begin
      // 5. Expansion: push further in the reflected direction
      SetLength(Expanded, N);
      for I := 0 to N - 1 do
        Expanded[I] := Centroid[I] + Gamma * (Reflected[I] - Centroid[I]);
      ErrExpanded := CalculateError(AMeasured, ABaseModel, Expanded);

      if ErrExpanded < ErrReflected then
      begin
        Simplex[N] := Expanded;
        Errors[N]  := ErrExpanded;
      end
      else
      begin
        Simplex[N] := Reflected;
        Errors[N]  := ErrReflected;
      end;
    end
    else if ErrReflected < Errors[N - 1] then
    begin
      // Reflection alone is good enough (better than second-worst)
      Simplex[N] := Reflected;
      Errors[N]  := ErrReflected;
    end
    else
    begin
      // 6. Contraction: pull back toward the centroid
      SetLength(Contracted, N);
      if ErrReflected < ErrWorst then
        for I := 0 to N - 1 do
          Contracted[I] := Centroid[I] + Rho * (Reflected[I] - Centroid[I])
      else
        for I := 0 to N - 1 do
          Contracted[I] := Centroid[I] + Rho * (Simplex[N][I] - Centroid[I]);

      ErrContracted := CalculateError(AMeasured, ABaseModel, Contracted);

      if ErrContracted < Min(ErrReflected, ErrWorst) then
      begin
        Simplex[N] := Contracted;
        Errors[N]  := ErrContracted;
      end
      else
      begin
        // 7. Shrink: move all points toward the best point
        for I := 1 to N do
        begin
          for J := 0 to N - 1 do
            Simplex[I][J] := Simplex[0][J] + Sigma * (Simplex[I][J] - Simplex[0][J]);
          Errors[I] := CalculateError(AMeasured, ABaseModel, Simplex[I]);
        end;
      end;
    end;
  end;

  // Select the best point of the final simplex
  J := 0;
  for I := 1 to N do
    if Errors[I] < Errors[J] then J := I;

  Result.FittedThicknesses := Copy(Simplex[J]);
  Result.SumSquaredError   := Errors[J];
  Result.SampleCount       := Length(AMeasured);
  Result.RMSError          := Sqrt(Errors[J] / (2 * Length(AMeasured)));
end;

end.
