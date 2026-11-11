unit Data.MeasurementCsv;

/// <summary>
/// Robust CSV reader/writer for measurement files.
/// Uses invariant culture for numeric parsing and formatting, so files
/// are portable across machines with different regional settings.
/// Validates that Wavelength > 0 and that Psi/Delta are within [0, 90] / [0, 360].
/// </summary>

interface

uses
  System.SysUtils, Domain.Types;

type
  /// <summary>
  /// Static CSV helper for TMeasurementArray.
  /// </summary>
  TMeasurementCsv = class
  public
    /// <summary>
    /// Loads measurements from a CSV file with a header row.
    /// Supports comma or semicolon delimiters.
    /// </summary>
    class function LoadFromFile(const AFileName: string): TMeasurementArray; static;

    /// <summary>
    /// Saves measurements to a CSV file with 6/8 decimal places.
    /// </summary>
    class procedure SaveToFile(const AFileName: string;
      const AMeasurements: TMeasurementArray); static;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.Generics.Collections,
  System.StrUtils;

/// <summary>
/// Parses a number that may use a decimal comma, using invariant culture.
/// </summary>
function ParseNumber(const S: string; out V: Double): Boolean;
var
  T: string;
begin
  T := Trim(S);
  // Accept decimal comma independent of Windows regional settings
  T := StringReplace(T, ',', '.', [rfReplaceAll]);
  Result := TryStrToFloat(T, V, TFormatSettings.Invariant);
end;

class function TMeasurementCsv.LoadFromFile(const AFileName: string): TMeasurementArray;
var
  Lines: TStringList;
  Items: TList<TMeasurement>;
  Delim: Char;
  I: Integer;
  Parts: TArray<string>;
  M: TMeasurement;
begin
  if not FileExists(AFileName) then
    raise EFileNotFoundException.Create('CSV file not found: ' + AFileName);

  Lines := TStringList.Create;
  Items := TList<TMeasurement>.Create;
  try
    Lines.LoadFromFile(AFileName, TEncoding.UTF8);

    if Lines.Count < 2 then
      raise EConvertError.Create('CSV must contain a header and at least one data row.');

    // Auto-detect delimiter from the header line
    if Pos(';', Lines[0]) > Pos(',', Lines[0]) then
      Delim := ';'
    else
      Delim := ',';

    // Skip header (row 0), parse data rows (1..Count-1)
    for I := 1 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) = '' then Continue;

      Parts := Lines[I].Split([Delim]);
      if Length(Parts) < 3 then
        raise EConvertError.CreateFmt(
          'Invalid CSV row %d: expected wavelength, psi, delta.', [I + 1]);

      if not ParseNumber(Parts[0], M.WavelengthNm) or
         not ParseNumber(Parts[1], M.PsiDeg) or
         not ParseNumber(Parts[2], M.DeltaDeg) then
        raise EConvertError.CreateFmt(
          'Invalid numeric value on CSV row %d.', [I + 1]);

      // Physical sanity checks
      if (M.WavelengthNm <= 0) or
         (M.PsiDeg < 0) or (M.PsiDeg > 90) or
         (M.DeltaDeg < 0) or (M.DeltaDeg > 360) then
        raise EConvertError.CreateFmt(
          'Value out of range on CSV row %d.', [I + 1]);

      Items.Add(M);
    end;

    if Items.Count = 0 then
      raise EConvertError.Create('CSV contains no measurements.');

    Result := Items.ToArray;
  finally
    Items.Free;
    Lines.Free;
  end;
end;

class procedure TMeasurementCsv.SaveToFile(const AFileName: string;
  const AMeasurements: TMeasurementArray);
var
  Lines: TStringList;
  I: Integer;
  FS: TFormatSettings;
begin
  // Invariant formatting ensures the file is portable across locales
  FS := TFormatSettings.Invariant;

  Lines := TStringList.Create;
  try
    Lines.Add('Wavelength_nm,Psi_deg,Delta_deg');

    for I := 0 to High(AMeasurements) do
      Lines.Add(Format('%.6f,%.8f,%.8f',
        [AMeasurements[I].WavelengthNm,
         AMeasurements[I].PsiDeg,
         AMeasurements[I].DeltaDeg], FS));

    // Ensure the target folder exists
    ForceDirectories(ExtractFileDir(ExpandFileName(AFileName)));
    Lines.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

end.
