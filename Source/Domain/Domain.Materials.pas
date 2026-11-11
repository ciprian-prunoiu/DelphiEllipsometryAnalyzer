unit Domain.Materials;

/// <summary>
/// In-memory library of common optical materials.
/// Each material stores its refractive index (N) and extinction coefficient (K)
/// at a representative wavelength (632.8 nm, the HeNe laser line).
/// The library is used to populate the Material ComboBox and to auto-fill
/// N and K when the user selects a material in the optical layers grid.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>
  /// Optical material description: name, N and K.
  /// </summary>
  TMaterialInfo = record
    Name: string;
    N: Double;
    K: Double;
    /// <summary>
    /// Convenience constructor for a material record.
    /// </summary>
    class function Create(const AName: string; const AN, AK: Double): TMaterialInfo; static;
  end;

  /// <summary>
  /// Static registry of optical materials.
  /// </summary>
  TMaterialLibrary = class
  private
    class var FItems: TDictionary<string, TMaterialInfo>;
  public
    /// <summary>
    /// Registers all default materials when the class is first used.
    /// </summary>
    class constructor Create;

    /// <summary>
    /// Frees the internal dictionary when the application exits.
    /// </summary>
    class destructor Destroy;

    /// <summary>
    /// Looks up a material by name. Returns a safe fallback (N=1, K=0) if not found.
    /// </summary>
    class function GetMaterial(const AName: string): TMaterialInfo;

    /// <summary>
    /// Fills a TStrings (e.g. TComboBox.Items) with all material names.
    /// </summary>
    class procedure PopulateComboBox(AItems: TStrings);
  end;

implementation

class constructor TMaterialLibrary.Create;
begin
  FItems := TDictionary<string, TMaterialInfo>.Create;

  // Common materials used in ellipsometry at 632.8 nm (HeNe laser)
  // N = refractive index, K = extinction coefficient
  FItems.Add('Air',      TMaterialInfo.Create('Air',      1.000, 0.000));
  FItems.Add('SiO2',     TMaterialInfo.Create('SiO2',     1.460, 0.000));
  FItems.Add('TiO2',     TMaterialInfo.Create('TiO2',     2.400, 0.000));
  FItems.Add('Si3N4',    TMaterialInfo.Create('Si3N4',    2.000, 0.000));
  FItems.Add('PMMA',     TMaterialInfo.Create('PMMA',     1.490, 0.000));
  FItems.Add('Gold',     TMaterialInfo.Create('Gold',     0.170, 3.100));
  FItems.Add('Silver',   TMaterialInfo.Create('Silver',   0.050, 3.900));
  FItems.Add('Silicon',  TMaterialInfo.Create('Silicon',  3.880, 0.020));
end;

class destructor TMaterialLibrary.Destroy;
begin
  FItems.Free;
end;

class function TMaterialInfo.Create(const AName: string; const AN, AK: Double): TMaterialInfo;
begin
  Result.Name := AName;
  Result.N := AN;
  Result.K := AK;
end;

class function TMaterialLibrary.GetMaterial(const AName: string): TMaterialInfo;
begin
  if not FItems.TryGetValue(AName, Result) then
  begin
    // Safe fallback so the UI never receives an uninitialised material
    Result.Name := AName;
    Result.N := 1.0;
    Result.K := 0.0;
  end;
end;

class procedure TMaterialLibrary.PopulateComboBox(AItems: TStrings);
var
  Pair: TPair<string, TMaterialInfo>;
begin
  AItems.Clear;
  for Pair in FItems do
    AItems.Add(Pair.Key);
end;

end.
