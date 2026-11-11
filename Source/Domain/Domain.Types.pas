unit Domain.Types;

/// <summary>
/// Core domain types shared across the ellipsometry application.
/// Defines the fundamental records for measurements and optical models.
/// </summary>

interface

type
  /// <summary>
  /// A single ellipsometric measurement at one wavelength.
  /// Psi and Delta are the standard ellipsometric angles in degrees.
  /// </summary>
  TMeasurement = record
    WavelengthNm: Double;
    PsiDeg: Double;
    DeltaDeg: Double;
  end;

  /// <summary>
  /// Convenience alias for an array of measurements (one full spectral scan).
  /// </summary>
  TMeasurementArray = TArray<TMeasurement>;

  /// <summary>
  /// A single thin-film layer in the optical stack.
  /// </summary>
  TOpticalLayer = record
    MaterialName: string;
    ThicknessNm: Double;
    N: Double;  // Refractive index
    K: Double;  // Extinction coefficient (absorption)
  end;

  /// <summary>
  /// Complete optical model: ambient, N thin films, and a substrate.
  /// </summary>
  TOpticalModel = record
    IncidenceAngleDeg: Double;
    AmbientN: Double;
    SubstrateN: Double;
    SubstrateK: Double;
    Layers: TArray<TOpticalLayer>;

    /// <summary>
    /// Returns the illustrative default model: air / 100 nm SiO2 / Si.
    /// </summary>
    class function Default: TOpticalModel; static;
  end;

implementation

class function TOpticalModel.Default: TOpticalModel;
begin
  // Air ambient
  Result.IncidenceAngleDeg := 70;
  Result.AmbientN := 1.0;

  // Silicon substrate (typical values at 632.8 nm)
  Result.SubstrateN := 3.88;
  Result.SubstrateK := 0.02;

  // Single SiO2 film, 100 nm thick
  SetLength(Result.Layers, 1);
  Result.Layers[0].MaterialName := 'SiO2';
  Result.Layers[0].ThicknessNm := 100;
  Result.Layers[0].N := 1.46;
  Result.Layers[0].K := 0;
end;

end.
